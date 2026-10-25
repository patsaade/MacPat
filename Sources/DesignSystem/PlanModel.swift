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
    /// Targets finished and targets in all, while a streaming scan runs.
    public private(set) var progress: (done: Int, total: Int)?
    /// The last scan was stopped. What is listed is what it found before that.
    public private(set) var scanCancelled = false
    /// Steps done and steps in all, while a real run is going.
    public private(set) var runProgress: (done: Int, total: Int)?
    private let stop = StopFlag()
    public private(set) var working = false
    public private(set) var scanned = false
    public private(set) var outcome: Outcome?
    /// The last step marked Never Touch, so the screen can offer an undo.
    public private(set) var neverTouched: Step?
    /// How the last real run split between the Trash and commands.
    public private(set) var lastRun = (trash: 0, commands: 0)
    /// The fingerprint of the last preview. Cleared by any change to the choice.
    public private(set) var previewed: String?
    public var showCommands = false
    /// Set by README snapshots, so one-time notes stay out of them.
    public var forSnapshot = false
    public var expanded: Set<String> = [] { didSet { saveState() } }
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

    public typealias Batch = @Sendable (_ index: Int, _ steps: [Step], _ done: Int, _ total: Int) -> Void

    /// Rebuilt whenever steps, sort, or dates change, so a redraw never sorts.
    public private(set) var groups: [(name: String, steps: [Step])] = []
    public private(set) var sortedGroups: [(name: String, steps: [Step])] = []
    public private(set) var largestBytes: Int64 = 0
    private var stepByID: [String: Step] = [:]
    private var choosableIDs: [String: [String]] = [:]

    private var source: @Sendable () async -> [Step]
    private var streamSource: (@Sendable (@escaping Batch) async -> Void)?
    private var scanTask: Task<Void, Never>?
    private var restart = false
    private var ignore = IgnoreList.load()
    private var stateKey: String?

    public init(executor: Executor, source: @escaping @Sendable () async -> [Step]) {
        self.executor = executor
        self.source = source
    }

    /// Swap what a scan looks at, for example after the user picks an app.
    public func setSource(_ source: @escaping @Sendable () async -> [Step]) {
        self.source = source
        streamSource = nil
        reset()
    }

    /// A source that reports as it goes, so rows appear while the scan runs and it can be stopped.
    public func setStreamingSource(_ source: @escaping @Sendable (@escaping Batch) async -> Void) {
        streamSource = source
        reset()
    }

    private func reset() {
        restart = true
        scanTask?.cancel()
        steps = []
        chosen = []
        scanned = false
        rebuild()
        invalidate()
    }

    /// Keeps the sort and the open groups between launches, under this name. Only names, never paths.
    public func remember(as key: String) {
        stateKey = key
        let saved = UserDefaults.standard.dictionary(forKey: "state.\(key)") ?? [:]
        if let raw = saved["sort"] as? String, let loaded = SortKey(rawValue: raw) { sortKey = loaded }
        sortAscending = saved["ascending"] as? Bool ?? false
        expanded = Set(saved["expanded"] as? [String] ?? [])
        rebuild()
    }

    /// `remember(as:)` for use in an initializer.
    public func remembering(_ key: String) -> PlanModel {
        remember(as: key)
        return self
    }

    private func saveState() {
        guard let stateKey else { return }
        UserDefaults.standard.set(
            ["sort": sortKey.rawValue, "ascending": sortAscending, "expanded": expanded.sorted()] as [String: Any],
            forKey: "state.\(stateKey)")
    }

    /// Stops a scan. Rows found so far stay.
    public func cancelScan() { scanTask?.cancel() }

    /// The rows you can see, top to bottom: steps of expanded groups, in sort order.
    public var visibleSteps: [Step] { sortedGroups.filter { expanded.contains($0.name) }.flatMap(\.steps) }
    public var selectedStep: Step? { selected.flatMap { stepByID[$0] } }

    private func rebuild() {
        var order: [String] = []
        var byGroup: [String: [Step]] = [:]
        for step in steps {
            if byGroup[step.group] == nil { order.append(step.group) }
            byGroup[step.group, default: []].append(step)
        }
        groups = order.map { ($0, byGroup[$0]!) }
        sortedGroups = groups.map { ($0.name, Self.order($0.steps, by: sortKey, ascending: sortAscending, modified: modified)) }
        stepByID = Dictionary(steps.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        choosableIDs = byGroup.mapValues { $0.filter { $0.risk != .locked }.map(\.id) }
        largestBytes = steps.map(\.bytes).max() ?? 0
    }

    /// Same column again flips the direction. A new column starts descending, except Name.
    public func sort(by key: SortKey) {
        if sortKey == key {
            sortAscending.toggle()
        } else {
            sortKey = key
            sortAscending = key == .name
        }
        saveState()
        rebuild()
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

    /// What a run would do, by kind, for the confirm dialog and the result banner.
    public var trashCount: Int { chosenSteps.filter { $0.action.movesToTrash }.count }
    public var commandCount: Int { chosenSteps.count - trashCount }
    public var reviewCount: Int { chosenSteps.filter { $0.risk == .review }.count }

    public func isOn(_ step: Step) -> Bool { chosen.contains(step.id) }

    public func toggle(_ step: Step) {
        guard step.risk != .locked else { return }
        if !chosen.insert(step.id).inserted { chosen.remove(step.id) }
        invalidate()
    }

    /// All on unless all are already on. Locked steps never join.
    public func toggleGroup(_ name: String) {
        let ids = choosableIDs[name] ?? []
        if ids.allSatisfy(chosen.contains) { chosen.subtract(ids) } else { chosen.formUnion(ids) }
        invalidate()
    }

    public func groupState(_ name: String) -> Bool? {
        let ids = choosableIDs[name] ?? []
        let on = ids.filter(chosen.contains).count
        return on == 0 ? false : on == ids.count ? true : nil
    }

    public func scan() async {
        if let running = scanTask {
            await running.value
            guard restart else { return }
        }
        restart = false
        let task = Task { await performScan() }
        scanTask = task
        await task.value
        scanTask = nil
    }

    private func performScan() async {
        scanning = true
        scanCancelled = false
        progress = nil
        previewed = nil
        // A dry run is stale after a scan. The result of a real run stays until the next run.
        if outcome?.dryRun == true { outcome = nil }
        let found: [Step]
        if let streamSource {
            found = await streamed(streamSource)
        } else {
            let source = source
            let work = Task.detached { await source() }
            found = await withTaskCancellationHandler {
                await work.value
            } onCancel: {
                work.cancel()
            }
        }
        scanCancelled = Task.isCancelled
        finish(found)
    }

    private struct Event: Sendable {
        let index: Int
        let steps: [Step]
        let done: Int
        let total: Int
    }

    /// Runs a streaming source and shows each batch the moment it arrives, in the source's own order.
    private func streamed(_ source: @escaping @Sendable (@escaping Batch) async -> Void) async -> [Step] {
        let (events, sink) = AsyncStream.makeStream(of: Event.self)
        let producer = Task.detached {
            await source { sink.yield(Event(index: $0, steps: $1, done: $2, total: $3)) }
            sink.finish()
        }
        steps = []
        var batches: [Int: [Step]] = [:]
        let ignore = ignore
        await withTaskCancellationHandler {
            for await event in events {
                batches[event.index] = event.steps.filter { step in step.url.map { !ignore.contains($0) } ?? true }
                var seen = Set<String>()
                steps = batches.keys.sorted().flatMap { batches[$0]! }.filter { seen.insert($0.id).inserted }
                progress = (event.done, event.total)
                rebuild()
            }
        } onCancel: {
            producer.cancel()
        }
        return steps
    }

    private func finish(_ found: [Step]) {
        let ignore = ignore
        steps = found.filter { step in step.url.map { !ignore.contains($0) } ?? true }
        var dates: [String: Date] = [:]
        for step in steps {
            if let date = step.modified {
                dates[step.id] = date
            } else if let url = step.url, steps.count < 500,
                let date = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
            {
                dates[step.id] = date
            }
        }
        modified = dates
        let ids = Set(steps.map(\.id))
        let keep = chosen.intersection(ids)
        chosen = scanned ? keep : Set(steps.filter { $0.preselected && $0.risk != .locked }.map(\.id))
        scanned = true
        scanning = false
        progress = nil
        rebuild()
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
        lastRun = (trashCount, commandCount)
        let (plan, executor, previewed) = (plan, executor, previewed)
        let stop = stop
        stop.reset()
        runProgress = (0, plan.steps.count)
        let result = await Task.detached {
            executor.run(plan, previewed: previewed, dryRun: false) { done, total in
                Task { @MainActor [weak self] in self?.runProgress = (done, total) }
                return !stop.isSet
            }
        }.value
        runProgress = nil
        await scan()
        outcome = result
        // Open the groups where something failed, so the reason is on screen.
        let failed = Set(result.failures.map(\.step))
        expanded.formUnion(steps.filter { failed.contains($0.id) }.map(\.group))
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
        rebuild()
        neverTouched = step
        invalidate()
    }

    /// Takes the last Never Touch back and looks again.
    public func undoNeverTouch() async {
        guard let step = neverTouched, let url = step.url else { return }
        ignore.remove(url.path)
        ignore.save()
        neverTouched = nil
        await scan()
    }

    /// Stops a run before its next step. The step in flight finishes.
    public func cancelRun() { stop.set() }

    public func dismissNeverTouched() { neverTouched = nil }

    private func invalidate() {
        previewed = nil
        outcome = nil
    }
}

/// A flag a run checks between steps. Set from the screen, read from the worker.
final class StopFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false
    var isSet: Bool { lock.withLock { value } }
    func set() { lock.withLock { value = true } }
    func reset() { lock.withLock { value = false } }
}
