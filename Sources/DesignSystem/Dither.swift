// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Patrick Saade

import SwiftUI

/// A 50% checkerboard of ink and paper, one point per cell, like a paint program's grey.
/// Increase Contrast swaps it for solid ink, so nothing depends on reading a texture.
public struct Dither: View {
    @Environment(\.colorSchemeContrast) private var contrast

    public init() {}

    public var body: some View {
        Group {
            if contrast == .increased {
                Retro.ink
            } else {
                Canvas { context, size in
                    var cells = Path()
                    for y in 0..<Int(size.height.rounded(.up)) {
                        for x in stride(from: y % 2, to: Int(size.width.rounded(.up)), by: 2) {
                            cells.addRect(CGRect(x: x, y: y, width: 1, height: 1))
                        }
                    }
                    context.fill(cells, with: .color(Retro.ink))
                }
                .background(Retro.paper)
            }
        }
        .accessibilityHidden(true)
    }
}

/// A 1-bit meter: an outlined box, dithered up to the fraction, with a solid edge where it stops.
public struct Bar: View {
    let fraction: Double
    let line: CGFloat

    public init(fraction: Double, line: CGFloat = 1) {
        self.fraction = fraction
        self.line = line
    }

    public var body: some View {
        GeometryReader { geo in
            let width = geo.size.width * min(max(fraction, 0), 1)
            ZStack(alignment: .leading) {
                Rectangle().fill(Retro.paper)
                Dither().frame(width: width)
                if width > 0 { Rectangle().fill(Retro.ink).frame(width: line).offset(x: max(0, width - line)) }
                Rectangle().strokeBorder(Retro.ink, lineWidth: line)
            }
        }
        .accessibilityHidden(true)
    }
}
