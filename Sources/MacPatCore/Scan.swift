// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Patrick Saade

import Foundation

public enum Risk: String, Codable, Sendable {
    case safe
    case review
}

/// A named group of places to clean. Paths are folders; their children are the items.
public struct Target: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let summary: String
    public let risk: Risk
    public let paths: [URL]

    public init(id: String, name: String, summary: String, risk: Risk, paths: [URL]) {
        self.id = id
        self.name = name
        self.summary = summary
        self.risk = risk
        self.paths = paths
    }
}

public struct Item: Identifiable, Hashable, Sendable {
    public let url: URL
    public let bytes: Int64
    public let targetID: String
    public var id: URL { url }

    public init(url: URL, bytes: Int64, targetID: String) {
        self.url = url
        self.bytes = bytes
        self.targetID = targetID
    }
}

public struct TargetScanner: Sendable {
    public let zones: Zones

    public init(zones: Zones) { self.zones = zones }

    /// Lists the children of each target path. Anything that fails
    /// validation is skipped. Nothing is changed on disk.
    public func scan(_ target: Target) -> [Item] {
        var seen = Set<URL>()
        var items: [Item] = []
        for path in target.paths where zones.contains(path) {
            let children = (try? FileManager.default.contentsOfDirectory(at: path, includingPropertiesForKeys: nil)) ?? []
            for child in children {
                guard let url = try? zones.validate(child), seen.insert(url).inserted else { continue }
                items.append(Item(url: url, bytes: Self.size(of: url), targetID: target.id))
            }
        }
        return items
    }

    /// Allocated size. The enumerator doesn't descend into symlinked folders.
    static func size(of url: URL) -> Int64 {
        let keys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey, .isDirectoryKey, .isSymbolicLinkKey]
        func own(_ u: URL) -> Int64 {
            Int64((try? u.resourceValues(forKeys: keys).totalFileAllocatedSize) ?? 0)
        }
        guard let values = try? url.resourceValues(forKeys: keys),
            values.isDirectory == true, values.isSymbolicLink != true,
            let walk = FileManager.default.enumerator(at: url, includingPropertiesForKeys: Array(keys), errorHandler: { _, _ in true })
        else { return own(url) }
        var total = own(url)
        for case let file as URL in walk { total += own(file) }
        return total
    }
}
