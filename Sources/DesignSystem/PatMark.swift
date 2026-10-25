// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Patrick Saade

import AppKit
import SwiftUI

/// The mark: a hand patting a computer. Same drawing as `docs/media/icon.svg`, without the
/// dither and with heavier lines, so it reads at menu bar size. Coordinates are on a 100-unit grid.
public struct PatMark: Shape {
    public init() {}

    public func path(in rect: CGRect) -> Path {
        let unit = CGAffineTransform(translationX: rect.minX, y: rect.minY).scaledBy(x: rect.width / 100, y: rect.height / 100)
        var ink = Path()
        let line = StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round)
        ink.addPath(Path(roundedRect: CGRect(x: 12, y: 52, width: 68, height: 34), cornerRadius: 7).strokedPath(line))
        ink.addRect(CGRect(x: 24, y: 61, width: 44, height: 16))
        ink.addRoundedRect(in: CGRect(x: 8, y: 91, width: 76, height: 8), cornerSize: CGSize(width: 2, height: 2))
        ink.addPath(Self.hand().applying(CGAffineTransform(translationX: 0, y: -4)))
        ink.addRect(CGRect(x: 86, y: 15, width: 14, height: 34))
        ink.addPath(
            Path { p in
                p.move(to: CGPoint(x: 34, y: 4))
                p.addLine(to: CGPoint(x: 34, y: 20))
                p.move(to: CGPoint(x: 26, y: 12))
                p.addLine(to: CGPoint(x: 42, y: 12))
            }.strokedPath(StrokeStyle(lineWidth: 6, lineCap: .round)))
        return ink.applying(unit)
    }

    /// Palm down, four fingertips to the left, thumb tucked under.
    static func hand() -> Path {
        Path { p in
            p.move(to: CGPoint(x: 88, y: 22.5))
            p.addCurve(to: CGPoint(x: 63, y: 24.5), control1: CGPoint(x: 80, y: 20.5), control2: CGPoint(x: 70, y: 21))
            p.addLine(to: CGPoint(x: 54, y: 24.5))
            p.addArc(center: CGPoint(x: 54, y: 27.6), radius: 3.1, startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: true)
            p.addLine(to: CGPoint(x: 48.5, y: 30.7))
            p.addArc(center: CGPoint(x: 48.5, y: 34), radius: 3.3, startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: true)
            p.addLine(to: CGPoint(x: 45, y: 37.3))
            p.addArc(center: CGPoint(x: 45, y: 40.6), radius: 3.3, startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: true)
            p.addLine(to: CGPoint(x: 47, y: 43.9))
            p.addArc(center: CGPoint(x: 47, y: 46.9), radius: 3, startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: true)
            p.addLine(to: CGPoint(x: 62, y: 49.9))
            p.addCurve(to: CGPoint(x: 88, y: 49.5), control1: CGPoint(x: 70, y: 51.2), control2: CGPoint(x: 80, y: 51))
            p.closeSubpath()
        }
    }

    /// A template image for the menu bar, so macOS tints it for light and dark.
    @MainActor public static let menuBarImage: NSImage = {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            context.addPath(PatMark().path(in: rect).cgPath)
            context.setFillColor(NSColor.black.cgColor)
            context.fillPath()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "MacPat"
        return image
    }()
}
