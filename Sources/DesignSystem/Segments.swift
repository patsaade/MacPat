// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Patrick Saade

import SwiftUI

/// A row of choices drawn like menu titles. The chosen one is inverted.
public struct RetroSegments<Value: Hashable>: View {
    let label: String
    let options: [(Value, String)]
    @Binding var selection: Value

    public init(_ label: String, options: [(Value, String)], selection: Binding<Value>) {
        self.label = label
        self.options = options
        _selection = selection
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.0) { value, title in
                Button(title) { selection = value }
                    .buttonStyle(RetroTabStyle(selected: value == selection))
                    .accessibilityAddTraits(value == selection ? .isSelected : [])
            }
        }
        .padding(1)
        .overlay(Rectangle().strokeBorder(Retro.ink, lineWidth: Retro.line))
        .fixedSize()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
    }
}
