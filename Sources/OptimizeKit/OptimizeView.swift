// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Patrick Saade

import AnalyzeKit
import DesignSystem
import MacPatCore
import SwiftUI

public struct OptimizeModule: MacPatModule {
    public let id = "optimize"
    public let title = "Optimize"
    public let symbol = "wrench.adjustable"

    public init() {}

    public func makeView() -> AnyView { AnyView(OptimizeView()) }
}

struct OptimizeView: View {
    @State private var model = PlanModel(executor: Executor(zones: Zones(roots: []), log: .standard())) {
        OptimizeTasks.steps(snapshots: VolumeSummary.read().snapshots)
    }

    init() {}

    init(demo model: PlanModel) { _model = State(initialValue: model) }

    var body: some View {
        PlanView(model: model, runLabel: "Run…", empty: "Nothing to run.") {
            RetroBanner(
                .info,
                "No \"free up memory\" or \"run maintenance scripts\" here. macOS does those itself, and forcing them makes things slower.")
        }
    }
}
