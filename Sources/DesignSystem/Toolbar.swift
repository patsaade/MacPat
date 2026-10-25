// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Patrick Saade

import SwiftUI

/// The strip at the top of a screen: controls on one line, 12 across and 8 down, with a rule under it.
public struct RetroToolbar<Content: View>: View {
    let content: Content

    public init(@ViewBuilder content: () -> Content) { self.content = content() }

    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) { content }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            RetroRule(thickness: 1)
        }
    }
}

private struct ModuleActiveKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    /// False for a module that is kept alive behind the one on screen. It should stop doing background work.
    public var moduleActive: Bool {
        get { self[ModuleActiveKey.self] }
        set { self[ModuleActiveKey.self] = newValue }
    }
}
