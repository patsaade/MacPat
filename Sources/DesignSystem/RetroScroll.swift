// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Patrick Saade

import SwiftUI

struct ScrollMetrics: Equatable {
    var offset: CGFloat = 0
    var content: CGFloat = 0
    var visible: CGFloat = 0

    var range: CGFloat { max(0, content - visible) }
    var scrolls: Bool { range > 1 }
}

/// A scroll view with a drawn 1-bit bar: dither track, boxed arrows, a square thumb with grip lines.
/// The real scroll view stays underneath with its own bar hidden, so trackpad inertia, rubber-banding,
/// paging keys, and VoiceOver scrolling all keep working. The bar only reads and sets the position.
public struct RetroScroll<Content: View>: View {
    private let content: Content
    @State private var position = ScrollPosition(edge: .top)
    @State private var metrics = ScrollMetrics()

    public init(@ViewBuilder content: () -> Content) { self.content = content() }

    public var body: some View {
        HStack(spacing: 0) {
            ScrollView { content }
                .scrollIndicators(.hidden)
                .scrollPosition($position)
                .onScrollGeometryChange(for: ScrollMetrics.self) { geo in
                    ScrollMetrics(offset: geo.contentOffset.y, content: geo.contentSize.height, visible: geo.containerSize.height)
                } action: { _, new in
                    metrics = new
                }
            RetroScrollBar(metrics: metrics, position: $position)
        }
    }
}

struct RetroScrollBar: View {
    let metrics: ScrollMetrics
    @Binding var position: ScrollPosition

    @Environment(\.accessibilityReduceMotion) private var reduce
    @State private var dragStart: CGFloat?
    @State private var hovering = false

    private static let width: CGFloat = 16
    private static let step: CGFloat = 40

    var body: some View {
        VStack(spacing: 0) {
            arrow(up: true)
            RetroRule(thickness: 2)
            track
            RetroRule(thickness: 2)
            arrow(up: false)
        }
        .frame(width: Self.width)
        .background(Retro.paper)
        .overlay(alignment: .leading) { Rectangle().fill(Retro.ink).frame(width: 3).offset(x: -3) }
        .padding(.leading, 3)
        .opacity(metrics.scrolls ? 1 : 0.35)
        .allowsHitTesting(metrics.scrolls)
        .accessibilityHidden(true)
    }

    private var track: some View {
        GeometryReader { geo in
            let height = geo.size.height
            let thumb = metrics.scrolls ? max(24, height * metrics.visible / metrics.content) : 0
            let travel = max(1, height - thumb)
            let y = metrics.scrolls ? travel * min(max(metrics.offset / metrics.range, 0), 1) : 0
            ZStack(alignment: .top) {
                if metrics.scrolls { Dither() } else { Retro.paper }
                if metrics.scrolls {
                    Thumb(dragging: dragStart != nil, hovering: hovering)
                        .frame(height: thumb)
                        .padding(.horizontal, 1)
                        .offset(y: y)
                        .onHover { hovering = $0 }
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { drag in
                                    let start = dragStart ?? metrics.offset
                                    dragStart = start
                                    scroll(to: start + drag.translation.height / travel * metrics.range, animated: false)
                                }
                                .onEnded { _ in dragStart = nil }
                        )
                }
            }
            .contentShape(Rectangle())
            .onTapGesture(coordinateSpace: .local) { point in
                guard metrics.scrolls else { return }
                let page = metrics.visible * 0.9
                scroll(to: metrics.offset + (point.y < y ? -page : page), animated: true)
            }
        }
    }

    private func arrow(up: Bool) -> some View {
        Button {
            scroll(to: metrics.offset + (up ? -Self.step : Self.step), animated: true)
        } label: {
            Triangle(up: up).frame(width: 8, height: 6).frame(width: Self.width, height: Self.width)
        }
        .buttonStyle(ArrowStyle())
    }

    private func scroll(to offset: CGFloat, animated: Bool) {
        let y = min(max(offset, 0), metrics.range)
        if animated && !reduce {
            withAnimation(Motion.quick) { position.scrollTo(y: y) }
        } else {
            position.scrollTo(y: y)
        }
    }
}

private struct Triangle: Shape {
    let up: Bool

    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.midX, y: up ? rect.minY : rect.maxY))
            p.addLine(to: CGPoint(x: rect.maxX, y: up ? rect.maxY : rect.minY))
            p.addLine(to: CGPoint(x: rect.minX, y: up ? rect.maxY : rect.minY))
            p.closeSubpath()
        }
    }
}

private struct ArrowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return configuration.label
            .foregroundStyle(pressed ? Retro.paper : Retro.ink)
            .background(pressed ? Retro.ink : Retro.paper)
            .contentShape(Rectangle().inset(by: -4))
    }
}

/// Square thumb with grip lines. A second inner edge on hover, solid ink while dragged.
private struct Thumb: View {
    let dragging: Bool
    let hovering: Bool

    var body: some View {
        let ink = dragging ? Retro.paper : Retro.ink
        ZStack {
            Rectangle().fill(dragging ? Retro.ink : Retro.paper)
            Rectangle().strokeBorder(Retro.ink, lineWidth: 2)
            if hovering && !dragging { Rectangle().strokeBorder(Retro.ink, lineWidth: 1).padding(3) }
            VStack(spacing: 2) {
                ForEach(0..<3, id: \.self) { _ in Rectangle().fill(ink).frame(height: 1) }
            }
            .padding(.horizontal, 3)
        }
    }
}
