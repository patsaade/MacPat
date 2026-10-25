// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Patrick Saade

#if DEBUG
    import Foundation
    import MacPatCore

    /// Fixture helpers for README snapshots. Debug builds only. Paths are made up, under /Users/pat.
    @MainActor
    public enum DemoKit {
        public static let home = URL(filePath: "/Users/pat")

        public static func url(_ rel: String) -> URL { rel.hasPrefix("/") ? URL(filePath: rel) : home.appending(path: rel) }

        /// A model already scanned from fixed steps. Dry runs only: its runner refuses everything.
        public static func model(_ steps: [Step], zones: [String] = [], expanded: [String] = [], preview: Bool = false) async -> PlanModel {
            let zones = Zones(roots: zones.map(url))
            let model = PlanModel(executor: Executor(zones: zones, home: home, dispose: { _ in }, runner: .none)) { steps }
            model.forSnapshot = true
            await model.scan()
            model.expanded = Set(expanded)
            if preview { await model.preview() }
            return model
        }
    }
#endif
