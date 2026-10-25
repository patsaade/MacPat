// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Patrick Saade

#if DEBUG
    import DesignSystem
    import SwiftUI

    @MainActor
    public enum OptimizeDemo {
        public static func view() async -> AnyView {
            let steps = OptimizeTasks.steps(snapshots: ["2026-10-24-091500"])
            let model = await DemoKit.model(steps, expanded: ["Network", "Finder and search"])
            model.showCommands = true
            return AnyView(OptimizeView(demo: model))
        }
    }
#endif
