// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Patrick Saade

import Foundation
import MacPatCore
import Observation

public enum SortKey: String, CaseIterable, Sendable {
    case name, size, verdict, modified
}

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
    /// Grid state: the highlighted row, whether its detail pane is open, and the column sort.
    public var selected: String?
    public var paneOpen = false
    public private(set) var sortKey: SortKey = .size
    public private(set) var sortAscending = false
    /// Last-modified time of each step's file, read during a scan.
    public private(set) var modified: [String: Date] = [:]
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

    /// Groups with their steps ordered by the current sort.
    public var sortedGroups: [(name: String, steps: [Step])] {
        groups.map { ($0.name, Self.order($0.steps, by: sortKey, ascending: sortAscending, modified: modified)) }
    }

    /// The rows you can see, top to bottom: steps of expanded groups, in sort order.
    public var visibleSteps: [Step] { sortedGroups.filter { expanded.contains($0.name) }.flatMap(\.steps) }
    public var selectedStep: Step? { steps.first { $0.id == selected } }

    /// Same column again flips the direction. A new column starts descending, except Name.
    public func sort(by key: SortKey) {
        if sortKey == key {
            sortAscending.toggle()
        } else {
            sortKey = key
            sortAscending = key == .name
        }
    }

    /// Moves the highlight up or down the visible rows. With nothing highlighted, takes the first.
    public func moveSelection(by delta: Int) {
        let rows = visibleSteps
        guard !rows.isEmpty else { return }
        let at = rows.firstIndex { $0.id == selected }
        selected = rows[at.map { min(max($0 + delta, 0), rows.count - 1) } ?? 0].id
    }

    public func select(_ step: Step, openPane: Bool) {
        selected = step.id
        if openPane { paneOpen = true }
    }

    public static func order(_ steps: [Step], by key: SortKey, ascending: Bool, modified: [String: Date]) -> [Step] {
        func rank(_ s: Step) -> Int { s.risk.rank }
        let result = steps.sorted { a, b in
            switch key {
            case .name: return a.title.localizedStandardCompare(b.title) == .orderedAscending
            case .size: return a.bytes != b.bytes ? a.bytes < b.bytes : a.title < b.title
            case .verdict: return rank(a) != rank(b) ? rank(a) < rank(b) : a.title < b.title
            case .modified:
                let (x, y) = (modified[a.id] ?? .distantPast, modified[b.id] ?? .distantPast)
                return x != y ? x < y : a.title < b.title
            }
        }
        return ascending ? result : result.reversed()
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
        sortKey = .size
        sortAscending = false
        let (found, dates) = await Task.detached { () async -> ([Step], [String: Date]) in
            let found = await source()
            var dates: [String: Date] = [:]
            for step in found {
                if let url = step.url, let date = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate {
                    dates[step.id] = date
                }
            }
            return (found, dates)
        }.value
        modified = dates
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
        if result.refused == nil && result.failures.isEmpty { Task { await PatSignal.shared.pat() } }
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
