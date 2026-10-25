// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Patrick Saade

import Foundation
import MacPatCore
import Testing

@testable import OptimizeKit

@Suite struct TaskTests {
    @Test func nothingPreselectedAndBadDatesDropped() {
        let steps = OptimizeTasks.steps(snapshots: ["2026-10-24-101500", "2026-10-24; rm"])
        #expect(steps.allSatisfy { !$0.preselected })
        #expect(steps.filter { $0.group.hasPrefix("Time Machine") }.count == 1)
        #expect(steps.contains { $0.display == "sudo /usr/bin/tmutil deletelocalsnapshots 2026-10-24-101500" })
    }

    @Test func dryRunRunsNothing() {
        let steps = OptimizeTasks.steps(snapshots: [])
        let ex = Executor(
            zones: Zones(roots: []),
            runner: Runner { _ in
                Issue.record("ran"); return ""
            })
        let out = ex.run(Plan(steps), previewed: nil, dryRun: true)
        #expect(out.count == steps.count && out.failures.isEmpty)
    }
}
