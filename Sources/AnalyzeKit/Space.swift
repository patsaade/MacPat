// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Patrick Saade

import Foundation
import MacPatCore

/// Where the space on the startup disk went, in the terms macOS uses.
public struct VolumeSummary: Sendable, Equatable {
    public var total: Int64 = 0
    public var free: Int64 = 0
    /// Free plus what macOS can purge for an app that asks: caches, iCloud copies, snapshots.
    public var important: Int64 = 0
    public var snapshots: [String] = []

    public var purgeable: Int64 { max(0, important - free) }
    public var used: Int64 { total - free }

    public static func read(_ volume: URL = URL(filePath: "/"), runner: Runner = .live) -> VolumeSummary {
        let keys: Set<URLResourceKey> = [
            .volumeTotalCapacityKey, .volumeAvailableCapacityKey, .volumeAvailableCapacityForImportantUsageKey,
        ]
        let values = try? volume.resourceValues(forKeys: keys)
        var summary = VolumeSummary()
        summary.total = Int64(values?.volumeTotalCapacity ?? 0)
        summary.free = Int64(values?.volumeAvailableCapacity ?? 0)
        summary.important = values?.volumeAvailableCapacityForImportantUsage ?? summary.free
        summary.snapshots = parseSnapshots((try? runner.run(.localSnapshots())) ?? "")
        return summary
    }

    /// `com.apple.TimeMachine.2026-10-24-101500.local` → `2026-10-24-101500`.
    static func parseSnapshots(_ text: String) -> [String] {
        text.matches(of: /com\.apple\.TimeMachine\.(\d{4}-\d{2}-\d{2}-\d{6})/).map { String($0.output.1) }
    }
}

/// One child of a folder, with its allocated size.
public struct Entry: Sendable, Identifiable, Hashable {
    public let url: URL
    public let bytes: Int64
    public let isFolder: Bool
    public var id: URL { url }
}

public enum FolderSizer {
    /// Sizes each child in parallel. Symlinks count as themselves. APFS clones are counted
    /// in full each time, so totals can be higher than the space they really use.
    public static func children(of folder: URL) async -> [Entry] {
        let urls =
            (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey]))
            ?? []
        return await withTaskGroup(of: Entry.self) { group in
            for url in urls {
                group.addTask {
                    let v = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey, .isPackageKey])
                    let folder = v?.isDirectory == true && v?.isSymbolicLink != true && v?.isPackage != true
                    return Entry(url: url, bytes: TargetScanner.size(of: url), isFolder: folder)
                }
            }
            var out: [Entry] = []
            for await entry in group { out.append(entry) }
            return out.sorted { $0.bytes > $1.bytes }
        }
    }
}

/// Big files nobody opened in a long time, outside ~/Library.
public struct LargeOldScanner: Sendable {
    public let home: URL
    public var minBytes: Int64 = 500_000_000
    public var minIdleDays = 180

    public init(home: URL) { self.home = home }

    /// The folders Analyze may move from. Fixed, and never Library. A symlinked one is dropped.
    public static let folders = ["Desktop", "Documents", "Downloads", "Movies", "Music", "Pictures", "Developer", "Public"]

    public static func zones(home: URL) -> Zones { Zones(home: home, relativePaths: folders) }

    static func lastUsed(_ url: URL) -> Date? {
        guard let item = MDItemCreateWithURL(nil, url as CFURL) else { return nil }
        return MDItemCopyAttribute(item, kMDItemLastUsedDate) as? Date
    }

    public func steps(now: Date = .now) -> [Step] {
        let zones = Self.zones(home: home)
        let keys: [URLResourceKey] = [.isRegularFileKey, .totalFileAllocatedSizeKey, .contentModificationDateKey]
        var steps: [Step] = []
        for root in zones.roots {
            guard
                let walk = FileManager.default.enumerator(
                    at: root, includingPropertiesForKeys: keys, options: [.skipsPackageDescendants], errorHandler: { _, _ in true })
            else { continue }
            for case let url as URL in walk {
                guard let v = try? url.resourceValues(forKeys: Set(keys)), v.isRegularFile == true,
                    let size = v.totalFileAllocatedSize, Int64(size) >= minBytes
                else { continue }
                let used = Self.lastUsed(url)
                let seen = used ?? v.contentModificationDate ?? now
                guard now.timeIntervalSince(seen) >= Double(minIdleDays) * 86_400, let valid = try? zones.validate(url) else { continue }
                steps.append(
                    Step(
                        group: "Large and old files", title: url.lastPathComponent, bytes: Int64(size), risk: .review,
                        reason:
                            "Over \(ByteCountFormatter.string(fromByteCount: minBytes, countStyle: .file)) and not opened in \(minIdleDays) days. Only you know if you still need it.",
                        facts: [Fact(used == nil ? "Modified" : "Last opened", seen.formatted(date: .abbreviated, time: .omitted))],
                        action: .trash(valid), preselected: false))
            }
        }
        return steps.sorted { $0.bytes > $1.bytes }
    }
}
