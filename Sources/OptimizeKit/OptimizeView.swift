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

    init() { model.remember(as: "optimize") }

    init(demo model: PlanModel) { _model = State(initialValue: model) }

    var body: some View {
        PlanView(
            model: model, layout: .grid,
            intro: Intro("optimize", "Each task says what it does, what it costs, and how to undo it. Some ask for your password."),
            runLabel: "Run…", empty: "Nothing to run."
        ) {
            RetroBanner(
                .info,
                "No \"free up memory\" or \"run maintenance scripts\" here. macOS does those itself, and forcing them makes things slower.")
        }
    }
}
