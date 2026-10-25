// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Patrick Saade

import SwiftUI

/// The paw mark, drawn as a path so it scales without bitmaps.
public struct PatMark: Shape {
    public init() {}

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        func oval(_ cx: Double, _ cy: Double, _ w: Double, _ h: Double) {
            path.addEllipse(
                in: CGRect(
                    x: rect.minX + (cx - w / 2) * rect.width, y: rect.minY + (cy - h / 2) * rect.height,
                    width: w * rect.width, height: h * rect.height))
        }
        oval(0.50, 0.68, 0.56, 0.44)
        oval(0.17, 0.42, 0.18, 0.24)
        oval(0.38, 0.22, 0.18, 0.26)
        oval(0.62, 0.22, 0.18, 0.26)
        oval(0.83, 0.42, 0.18, 0.24)
        return path
    }
}
