// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Patrick Saade

import AppKit
import SwiftUI

/// The mark: a hand patting a square Mac. Same drawing as `docs/media/icon.svg`, without the
/// dither and with heavier lines, so it reads at menu bar size. Coordinates are on a 100-unit grid.
public struct PatMark: Shape {
    /// How far the hand is raised, in grid units. Zero is resting on the screen.
    public var lift: CGFloat

    public init(lift: CGFloat = 0) { self.lift = lift }

    public var animatableData: CGFloat {
        get { lift }
        set { lift = newValue }
    }

    public func path(in rect: CGRect) -> Path {
        let unit = CGAffineTransform(translationX: rect.minX, y: rect.minY).scaledBy(x: rect.width / 100, y: rect.height / 100)
        return Self.resting(lift: lift).applying(unit)
    }

    /// The three pieces, built once in 100-unit coordinates with the hand at rest. Boolean path
    /// operations are slow, so nothing here is rebuilt per frame.
    struct Parts: Sendable {
        let mac: Path
        let halo: Path
        let hand: Path
    }

    static let parts: Parts = {
        var mac = Path()
        mac.addPath(Path(roundedRect: CGRect(x: 11.5, y: 17.5, width: 77, height: 77), cornerRadius: 6).strokedPath(.init(lineWidth: 7)))
        mac.addPath(Path(roundedRect: CGRect(x: 21, y: 27, width: 58, height: 42), cornerRadius: 2).strokedPath(.init(lineWidth: 5)))
        mac.addRect(CGRect(x: 28, y: 81, width: 44, height: 5))
        var splits = Path()
        for (x, end) in [(41.0, 51.0), (50.0, 55.0), (59.0, 51.0)] {
            splits.move(to: CGPoint(x: x, y: 36))
            splits.addLine(to: CGPoint(x: x, y: end))
        }
        let place = CGAffineTransform(translationX: 14, y: -4).scaledBy(x: 0.75, y: 0.75)
        let hand = fingers(extra: 0).subtracting(splits.strokedPath(.init(lineWidth: 2.4))).applying(place)
        // A gap around the hand keeps it readable where it overlaps the screen.
        return Parts(mac: mac, halo: fingers(extra: 7).applying(place), hand: hand)
    }()

    /// Mac minus the hand's halo, plus the hand. Cached at rest; other lifts are built on demand (menu bar only).
    static func resting(lift: CGFloat) -> Path {
        if lift == 0 { return restingPath }
        return compose(lift: lift)
    }

    private static let restingPath = compose(lift: 0)

    private static func compose(lift: CGFloat) -> Path {
        let up = CGAffineTransform(translationX: 0, y: -lift)
        var ink = parts.mac.subtracting(parts.halo.applying(up))
        ink.addPath(parts.hand.applying(up))
        return ink
    }

    /// The hand as a union of capsules and a palm, widened by `extra`.
    static func fingers(extra: CGFloat) -> Path {
        var p = Path()
        let cap = { (w: CGFloat) in StrokeStyle(lineWidth: w + extra, lineCap: .round) }
        // Union, not addPath: overlapping pieces with opposite winding would punch holes.
        for (x, tip, w) in [(36.5, 54.0, 9.0), (45.5, 59.0, 9.0), (54.5, 56.0, 9.0), (63.5, 48.0, 9.0)] {
            p = p.union(
                Path {
                    $0.move(to: CGPoint(x: x, y: 30)); $0.addLine(to: CGPoint(x: x, y: tip))
                }.strokedPath(cap(w)))
        }
        p = p.union(
            Path {
                $0.move(to: CGPoint(x: 34, y: 20)); $0.addLine(to: CGPoint(x: 23, y: 36))
            }.strokedPath(cap(9)))
        p = p.union(Path(roundedRect: CGRect(x: 32 - extra / 2, y: 10 - extra / 2, width: 36 + extra, height: 26 + extra), cornerRadius: 8))
        return p.union(Path(CGRect(x: 30 - extra / 2, y: 1 - extra / 2, width: 40 + extra, height: 11 + extra)))
    }

    /// A template image for the menu bar, so macOS tints it for light and dark.
    @MainActor public static func menuBar(lift: CGFloat = 0) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            context.addPath(PatMark(lift: lift).path(in: rect).cgPath)
            context.setFillColor(NSColor.black.cgColor)
            context.fillPath()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "MacPat"
        return image
    }

    @MainActor public static let menuBarImage = menuBar()
}

/// The mark drawn in layers, cheap enough to redraw every frame: the Mac, a paper-colored gap, the hand.
struct PatPicture: View {
    var lift: CGFloat

    var body: some View {
        Canvas { context, size in
            let unit = CGAffineTransform(scaleX: size.width / 100, y: size.height / 100)
            let up = CGAffineTransform(translationX: 0, y: -lift).concatenating(unit)
            let parts = PatMark.parts
            context.fill(parts.mac.applying(unit), with: .color(Retro.ink))
            context.fill(parts.halo.applying(up), with: .color(Retro.paper))
            context.fill(parts.hand.applying(up), with: .color(Retro.ink))
        }
    }
}
