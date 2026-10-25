// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Patrick Saade

import Foundation
import MacPatCore

/// Maintenance jobs, each a fixed command with what it does, what it costs, and how to undo it.
/// Nothing is preselected. These are fixes for specific problems, not routine care.
public enum OptimizeTasks {
    public static func steps(snapshots: [String]) -> [Step] {
        var steps = snapshots.compactMap { date -> Step? in
            guard let command = try? Command.deleteSnapshot(date) else { return nil }
            return Step(
                group: "Time Machine local snapshots", title: "Snapshot \(date)", risk: .review,
                reason: "Holds deleted files until Time Machine backs up. Deleting it frees that space now.",
                facts: [Fact("Undo", "None. Deleted for good, not to the Trash. Backups on your backup disk are not touched.")],
                action: .command(command), preselected: false)
        }
        steps += [
            Step(
                group: "Network", title: "Flush the DNS cache", risk: .safe,
                reason: "Fixes sites that moved but still resolve to the old address.",
                facts: [Fact("Cost", "The next few lookups are slower."), Fact("Undo", "Not needed. The cache refills.")],
                action: .sequence([.command(.flushDNS()), .command(.restartResolver())]), preselected: false),
            Step(
                group: "Finder and search", title: "Rebuild the Launch Services database", risk: .review,
                reason: "Fixes duplicate or missing apps in Open With, and wrong default apps.",
                facts: [Fact("Cost", "Takes a minute. Some default apps may need setting again."), Fact("Undo", "None needed.")],
                action: .command(.rebuildLaunchServices()), preselected: false),
            Step(
                group: "Finder and search", title: "Reset the Quick Look cache", risk: .safe,
                reason: "Fixes stale or blank previews and thumbnails.",
                facts: [Fact("Cost", "Thumbnails redraw once."), Fact("Undo", "Not needed.")],
                action: .command(.resetQuickLook()), preselected: false),
            Step(
                group: "Finder and search", title: "Rebuild the Spotlight index", risk: .review,
                reason: "Fixes search that misses files it should find.",
                facts: [Fact("Cost", "Search is incomplete and the Mac works harder for an hour or more."), Fact("Undo", "None needed.")],
                action: .command(.reindexSpotlight()), preselected: false),
        ]
        return steps
    }
}
