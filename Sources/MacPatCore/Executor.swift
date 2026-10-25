// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Patrick Saade

import Foundation

public struct Failure: Equatable, Sendable {
    public let step: String
    public let reason: String
}

public struct Outcome: Equatable, Sendable {
    public let dryRun: Bool
    public var count = 0
    public var bytes: Int64 = 0
    public var failures: [Failure] = []
    /// Set when the whole run was refused before any step ran.
    public var refused: String?
    /// Steps left unrun because the user stopped the run. Each step that did start finished.
    public var skipped = 0

    public init(dryRun: Bool) { self.dryRun = dryRun }

    public func failure(for step: Step) -> String? { failures.first { $0.step == step.id }?.reason }
}

/// Runs a plan. Every step is checked again right before it runs.
public struct Executor: Sendable {
    public typealias Dispose = @Sendable (URL) throws -> Void

    /// Moves to the Trash. MacPat never deletes a file itself. Two allowlisted commands do
    /// delete by design (unavailable simulators, local snapshots), and their steps say so.
    public static let trash: Dispose = { try FileManager.default.trashItem(at: $0, resultingItemURL: nil) }

    public let zones: Zones
    public let system: Zones
    let home: URL
    let dispose: Dispose
    let runner: Runner
    let log: ActionLog?

    public init(
        zones: Zones, system: Zones = .system, home: URL = FileManager.default.homeDirectoryForCurrentUser,
        dispose: @escaping Dispose = Executor.trash, runner: Runner = .live, log: ActionLog? = nil
    ) {
        self.zones = zones
        self.system = system
        self.home = home
        self.dispose = dispose
        self.runner = runner
        self.log = log
    }

    /// A dry run checks every step and runs none. A real run needs the fingerprint of the
    /// preview the user saw; anything else is refused. Failures are listed, never fatal.
    // shortcut: a path can still change between validate and dispose. Admin moves run as root, but only
    // from root-owned zone folders into a randomly named Trash path; a held directory handle would close it fully.
    /// `progress` is asked before each step with how many are done and how many there are. Answer false to
    /// stop. A step is never interrupted once it starts.
    public func run(
        _ plan: Plan, previewed: String?, dryRun: Bool, progress: (@Sendable (_ done: Int, _ total: Int) -> Bool)? = nil
    ) -> Outcome {
        var outcome = Outcome(dryRun: dryRun)
        if !dryRun, previewed != plan.fingerprint {
            outcome.refused = SafetyError.planChanged.description
            return outcome
        }
        var done = Set<String>()
        let total = plan.steps.count
        for (index, step) in plan.steps.enumerated() where done.insert(step.id).inserted {
            if let progress, !progress(index, total) {
                outcome.skipped = total - index
                break
            }
            do {
                guard step.risk != .locked else { throw SafetyError.locked }
                if case .sequence(let all) = step.action {
                    // Check every part before running any of it.
                    for part in all { try perform(part, dryRun: true) }
                    if !dryRun { for part in all { try perform(part, dryRun: false) } }
                } else {
                    try perform(step.action, dryRun: dryRun)
                }
                outcome.count += 1
                outcome.bytes += step.bytes
            } catch {
                outcome.failures.append(Failure(step: step.id, reason: "\(error)"))
            }
        }
        if !dryRun { log?.append(plan, outcome) }
        return outcome
    }

    private func perform(_ action: Action, dryRun: Bool) throws {
        switch action {
        case .trash(let url):
            let url = try zones.validate(url)
            if !dryRun { try dispose(url) }
        case .adminTrash(let url):
            let command = try Command.moveToTrash(try system.validate(url), home: home)
            if !dryRun { _ = try runner.run(command) }
        case .command(let command):
            if !dryRun { _ = try runner.run(command) }
        case .sequence:
            throw SafetyError.badArgument("nested sequence")
        case .none:
            throw SafetyError.locked
        }
    }
}
