// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Patrick Saade

import Foundation
import MacPatCore
import Observation

/// Scan, choose, preview, run. Shared by every module that changes anything.
/// A real run unlocks only after a preview of the exact same choice.
@MainActor @Observable
public final class PlanModel {
    public private(set) var steps: [Step] = []
    public private(set) var chosen: Set<String> = []
    public private(set) var scanning = false
    public private(set) var working = false
    public private(set) var scanned = false
    public private(set) var outcome: Outcome?
    /// The fingerprint of the last preview. Cleared by any change to the choice.
    public private(set) var previewed: String?
    public var showCommands = false
    public var expanded: Set<String> = []
    public var executor: Executor {
        didSet { invalidate() }
    }

    private var source: @Sendable () async -> [Step]
    private var ignore = IgnoreList.load()

    public init(executor: Executor, source: @escaping @Sendable () async -> [Step]) {
        self.executor = executor
        self.source = source
    }

    /// Swap what a scan looks at, for example after the user picks an app.
    public func setSource(_ source: @escaping @Sendable () async -> [Step]) {
        self.source = source
        steps = []
        chosen = []
        scanned = false
        invalidate()
    }

    public var groups: [(name: String, steps: [Step])] {
        var order: [String] = []
        var byGroup: [String: [Step]] = [:]
        for step in steps {
            if byGroup[step.group] == nil { order.append(step.group) }
            byGroup[step.group, default: []].append(step)
        }
        return order.map { ($0, byGroup[$0]!) }
    }

    public var chosenSteps: [Step] { steps.filter { chosen.contains($0.id) } }
    public var chosenBytes: Int64 { chosenSteps.reduce(0) { $0 + $1.bytes } }
    public var adminCount: Int { chosenSteps.filter(\.needsAdmin).count }
    public var plan: Plan { Plan(chosenSteps) }

    public func isOn(_ step: Step) -> Bool { chosen.contains(step.id) }

    public func toggle(_ step: Step) {
        guard step.risk != .locked else { return }
        if !chosen.insert(step.id).inserted { chosen.remove(step.id) }
        invalidate()
    }

    /// All on unless all are already on. Locked steps never join.
    public func toggleGroup(_ name: String) {
        let ids = steps.filter { $0.group == name && $0.risk != .locked }.map(\.id)
        if ids.allSatisfy(chosen.contains) { chosen.subtract(ids) } else { chosen.formUnion(ids) }
        invalidate()
    }

    public func groupState(_ name: String) -> Bool? {
        let ids = steps.filter { $0.group == name && $0.risk != .locked }.map(\.id)
        let on = ids.filter(chosen.contains).count
        return on == 0 ? false : on == ids.count ? true : nil
    }

    public func scan() async {
        scanning = true
        invalidate()
        let source = source
        let found = await Task.detached { await source() }.value
        let ignore = ignore
        steps = found.filter { step in step.url.map { !ignore.contains($0) } ?? true }
        let ids = Set(steps.map(\.id))
        let keep = chosen.intersection(ids)
        chosen = scanned ? keep : Set(steps.filter { $0.preselected && $0.risk != .locked }.map(\.id))
        scanned = true
        scanning = false
    }

    public func preview() async {
        working = true
        let (plan, executor) = (plan, executor)
        outcome = await Task.detached { executor.run(plan, previewed: nil, dryRun: true) }.value
        previewed = plan.fingerprint
        working = false
    }

    public func run() async {
        working = true
        let (plan, executor, previewed) = (plan, executor, previewed)
        let result = await Task.detached { executor.run(plan, previewed: previewed, dryRun: false) }.value
        await scan()
        outcome = result
        working = false
    }

    /// Adds the path to the ignore list and drops it from this scan.
    public func neverTouch(_ step: Step) {
        guard let url = step.url else { return }
        ignore.add(url)
        ignore.save()
        steps.removeAll { $0.id == step.id }
        chosen.remove(step.id)
        invalidate()
    }

    private func invalidate() {
        previewed = nil
        outcome = nil
    }
}
