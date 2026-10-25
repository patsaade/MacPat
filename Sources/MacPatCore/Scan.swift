// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Patrick Saade

import Foundation

/// How sure MacPat is that a step is harmless. Locked steps never run.
public enum Risk: String, Codable, Sendable, CaseIterable {
    case safe
    case review
    case locked
}

/// A named group of places to clean. Paths are folders; their children are the items.
public struct Target: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let summary: String
    public let risk: Risk
    public let paths: [URL]
    /// Why removing these is fine, and what it costs to get them back.
    public var reason = ""
    public var regenerates = ""
    /// Filename globs. Empty means every child.
    public var match: [String] = []
    public var exclude: [String] = []
    /// Only children not modified for this many days.
    public var minAgeDays = 0
    /// Paths are system folders. Items need admin to move.
    public var system = false
    public var group = ""
    /// Chosen after a scan. Defaults to safe targets only.
    public var preselect: Bool?
    /// A command that does the job instead of moving files.
    public var command: Command?
    /// Names extra facts to read for each item, such as where a download came from.
    public var details: String?

    public init(id: String, name: String, summary: String, risk: Risk, paths: [URL]) {
        self.id = id
        self.name = name
        self.summary = summary
        self.risk = risk
        self.paths = paths
    }

    func wants(_ url: URL, now: Date) -> Bool {
        let name = url.lastPathComponent
        guard match.isEmpty || match.contains(where: { fnmatch($0, name, FNM_CASEFOLD) == 0 }),
            !exclude.contains(where: { fnmatch($0, name, FNM_CASEFOLD) == 0 })
        else { return false }
        guard minAgeDays > 0 else { return true }
        let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? now
        return now.timeIntervalSince(modified) >= Double(minAgeDays) * 86_400
    }
}

public struct Item: Identifiable, Hashable, Sendable {
    public let url: URL
    public let bytes: Int64
    public let targetID: String
    public let modified: Date?
    public var id: URL { url }

    public init(url: URL, bytes: Int64, targetID: String, modified: Date? = nil) {
        self.url = url
        self.bytes = bytes
        self.targetID = targetID
        self.modified = modified
    }
}

public struct TargetScanner: Sendable {
    public let zones: Zones

    public init(zones: Zones) { self.zones = zones }

    /// Lists the children of each target path. Anything that fails
    /// validation is skipped. Nothing is changed on disk.
    public func scan(_ target: Target, now: Date = .now) -> [Item] { report(target, now: now).items }

    /// Like `scan`, and also says which folders exist but could not be read, usually because macOS
    /// has not allowed MacPat in. A folder that isn't there is not a problem.
    public func report(_ target: Target, now: Date = .now) -> (items: [Item], unreadable: [URL]) {
        var seen = Set<URL>()
        var items: [Item] = []
        var unreadable: [URL] = []
        for path in target.paths where zones.contains(path) {
            let children: [URL]
            do {
                children = try FileManager.default.contentsOfDirectory(at: path, includingPropertiesForKeys: [.contentModificationDateKey])
            } catch {
                if FileManager.default.fileExists(atPath: path.path) { unreadable.append(path) }
                continue
            }
            var found: [(url: URL, modified: Date?)] = []
            for child in children where target.wants(child, now: now) {
                guard let url = try? zones.validate(child), seen.insert(url).inserted else { continue }
                found.append((url, try? child.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate))
            }
            if Task.isCancelled { break }
            let sizes = Self.sizes(of: found.map(\.url))
            for (entry, bytes) in zip(found, sizes) {
                items.append(Item(url: entry.url, bytes: bytes, targetID: target.id, modified: entry.modified))
            }
        }
        return (items, unreadable)
    }

    /// Sizes several items at once. Each is an independent walk, so they run side by side.
    static func sizes(of urls: [URL]) -> [Int64] { concurrentMap(urls) { size(of: $0) } }

    /// Allocated size. The enumerator doesn't descend into symlinked folders.
    public static func size(of url: URL) -> Int64 {
        let keys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey, .isDirectoryKey, .isSymbolicLinkKey]
        func own(_ u: URL) -> Int64 {
            Int64((try? u.resourceValues(forKeys: keys).totalFileAllocatedSize) ?? 0)
        }
        guard let values = try? url.resourceValues(forKeys: keys),
            values.isDirectory == true, values.isSymbolicLink != true,
            let walk = FileManager.default.enumerator(at: url, includingPropertiesForKeys: Array(keys), errorHandler: { _, _ in true })
        else { return own(url) }
        var total = own(url)
        for case let file as URL in walk {
            if Task.isCancelled { break }  // a stopped scan drops what it was sizing
            total += own(file)
        }
        return total
    }
}
