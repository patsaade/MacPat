// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Patrick Saade

import AppKit
import SwiftUI

/// A 1-bit look: pure ink on pure paper. Light mode is black on white, dark mode swaps them.
/// Everything is drawn with shapes and the system monospaced font. No bitmaps, no borrowed artwork.
public enum Retro {
    public static let ink = Color(nsColor: NSColor(name: nil) { $0.isDark ? .white : .black })
    public static let paper = Color(nsColor: NSColor(name: nil) { $0.isDark ? .black : .white })
    public static let font = Font.system(.body, design: .monospaced)
    public static let line: CGFloat = 2
}

extension NSAppearance {
    fileprivate var isDark: Bool { bestMatch(from: [.darkAqua, .aqua]) == .darkAqua }
}

/// A thin or thick rule in ink.
public struct RetroRule: View {
    let thickness: CGFloat

    public init(thickness: CGFloat = Retro.line) { self.thickness = thickness }

    public var body: some View {
        Rectangle().fill(Retro.ink).frame(height: thickness).accessibilityHidden(true)
    }
}

/// The dotted desktop. Plain paper when Increase Contrast is on.
public struct RetroDesktop: View {
    @Environment(\.colorSchemeContrast) private var contrast

    public init() {}

    public var body: some View {
        Canvas { context, size in
            var dots = Path()
            for y in stride(from: 0, to: size.height, by: 6) {
                for x in stride(from: 0, to: size.width, by: 6) {
                    dots.addRect(CGRect(x: x, y: y, width: 2, height: 2))
                }
            }
            context.fill(dots, with: .color(Retro.ink))
        }
        .opacity(contrast == .increased ? 0 : 1)
        .background(Retro.paper)
        .accessibilityHidden(true)
    }
}

/// A window panel: striped title bar, heavy outline, hard shadow.
public struct RetroWindow<Content: View>: View {
    let title: String
    let content: Content

    public init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    public var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Canvas { context, size in
                    var stripes = Path()
                    for y in stride(from: 5, to: size.height - 4, by: 3) {
                        stripes.addRect(CGRect(x: 4, y: y, width: size.width - 8, height: 1))
                    }
                    context.fill(stripes, with: .color(Retro.ink))
                }
                .accessibilityHidden(true)
                Text(title)
                    .font(Retro.font.bold())
                    .padding(.horizontal, 10)
                    .background(Retro.paper)
                    .accessibilityAddTraits(.isHeader)
            }
            .frame(height: 24)
            RetroRule()
            content
        }
        .background(Retro.paper)
        .overlay(Rectangle().strokeBorder(Retro.ink, lineWidth: Retro.line))
        .background(alignment: .topLeading) { Rectangle().fill(Retro.ink).offset(x: 6, y: 6) }
    }
}

/// A dashed ring that shows where keyboard focus is.
private struct FocusRing: ViewModifier {
    @Environment(\.isFocused) private var focused
    let radius: CGFloat

    func body(content: Content) -> some View {
        content.overlay {
            if focused {
                RoundedRectangle(cornerRadius: radius + 3)
                    .stroke(Retro.ink, style: StrokeStyle(lineWidth: 2, dash: [3, 3]))
                    .padding(-5)
            }
        }
    }
}

/// Rounded button. Inverts while pressed. Disabled buttons get a dashed outline, so state is not only dimming.
public struct RetroButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View { Inner(configuration: configuration) }

    private struct Inner: View {
        let configuration: ButtonStyleConfiguration
        @Environment(\.isEnabled) private var enabled

        var body: some View {
            let shape = RoundedRectangle(cornerRadius: 6)
            let pressed = configuration.isPressed
            configuration.label
                .font(Retro.font)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .foregroundStyle(pressed ? Retro.paper : Retro.ink)
                .background(pressed ? Retro.ink : Retro.paper, in: shape)
                .overlay(shape.strokeBorder(Retro.ink, style: StrokeStyle(lineWidth: Retro.line, dash: enabled ? [] : [4, 3])))
                .background { if enabled && !pressed { shape.fill(Retro.ink).offset(x: 3, y: 3) } }
                .offset(x: pressed ? 3 : 0, y: pressed ? 3 : 0)
                .motion(pressed ? Motion.quick : Motion.release, value: pressed)
                .padding([.trailing, .bottom], 3)
                .opacity(enabled ? 1 : 0.6)
                .modifier(FocusRing(radius: 6))
                .contentShape(shape)
        }
    }
}

/// Square box with an X.
public struct RetroToggleStyle: ToggleStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Box(isOn: configuration.isOn)
                configuration.label
            }
            // A 24 pt target around the 16 pt box, without moving anything.
            .padding(4)
            .contentShape(Rectangle())
            .padding(-4)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(configuration.isOn ? "On" : "Off")
    }

    private struct Box: View {
        let isOn: Bool
        @Environment(\.isEnabled) private var enabled

        var body: some View {
            ZStack {
                Rectangle().fill(Retro.paper)
                Rectangle().strokeBorder(Retro.ink, style: StrokeStyle(lineWidth: Retro.line, dash: enabled ? [] : [3, 2]))
                if isOn {
                    Path { p in
                        p.move(to: CGPoint(x: 3, y: 3))
                        p.addLine(to: CGPoint(x: 13, y: 13))
                        p.move(to: CGPoint(x: 13, y: 3))
                        p.addLine(to: CGPoint(x: 3, y: 13))
                    }
                    .stroke(Retro.ink, lineWidth: Retro.line)
                }
            }
            .frame(width: 16, height: 16)
            .modifier(FocusRing(radius: 0))
            .opacity(enabled ? 1 : 0.6)
            .accessibilityHidden(true)
        }
    }
}

/// A menu-bar title. Inverted when selected.
public struct RetroTabStyle: ButtonStyle {
    let selected: Bool

    public init(selected: Bool) { self.selected = selected }

    public func makeBody(configuration: Configuration) -> some View {
        let inverted = selected != configuration.isPressed
        return configuration.label
            .font(Retro.font)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .foregroundStyle(inverted ? Retro.paper : Retro.ink)
            .background(inverted ? Retro.ink : Retro.paper)
            .modifier(FocusRing(radius: 0))
            .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
