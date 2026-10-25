// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Patrick Saade

import Foundation
import MacPatCore
import Observation

@MainActor @Observable
public final class CleanModel {
    public private(set) var targets: [Target] = []
    public private(set) var loadError: String?
    public private(set) var items: [String: [Item]] = [:]
    public private(set) var selected: Set<String> = []
    public private(set) var scanning = false
    public private(set) var working = false
    public private(set) var outcome: Outcome?
    /// A preview of the current selection has run. Trashing stays off until then.
    public private(set) var previewed = false

    private let scanner: TargetScanner
    private let cleaner: Cleaner

    public init(home: URL = FileManager.default.homeDirectoryForCurrentUser, rules: URL = RuleLoader.bundledDirectory) {
        let zones = Zones(home: home)
        scanner = TargetScanner(zones: zones)
        cleaner = Cleaner(zones: zones)
        do {
            targets = try RuleLoader.load(from: rules, home: home, zones: zones)
        } catch {
            loadError = "\(error)"
        }
    }

    public var chosenItems: [Item] { selected.sorted().flatMap { items[$0] ?? [] } }
    public var chosenBytes: Int64 { chosenItems.reduce(0) { $0 + $1.bytes } }

    public func toggle(_ id: String) {
        if !selected.insert(id).inserted { selected.remove(id) }
        previewed = false
        outcome = nil
    }

    public func scan() async {
        scanning = true
        previewed = false
        outcome = nil
        let (targets, scanner) = (targets, scanner)
        items = await Task.detached { Dictionary(uniqueKeysWithValues: targets.map { ($0.id, scanner.scan($0)) }) }.value
        selected = selected.filter { items[$0]?.isEmpty == false }
        scanning = false
    }

    public func run(dryRun: Bool) async {
        working = true
        let (chosen, cleaner) = (chosenItems, cleaner)
        let result = await Task.detached { cleaner.run(chosen, dryRun: dryRun) }.value
        if dryRun { previewed = true } else { await scan() }
        outcome = result
        working = false
    }
}
