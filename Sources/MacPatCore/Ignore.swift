// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Patrick Saade

import Foundation

/// Paths the user marked "Never touch". Scans drop them and anything inside them.
public struct IgnoreList: Sendable, Equatable {
    public private(set) var paths: [String]

    public init(paths: [String] = []) { self.paths = paths }

    static let key = "ignore"

    public static func load(_ defaults: UserDefaults = .standard) -> IgnoreList {
        IgnoreList(paths: defaults.stringArray(forKey: key) ?? [])
    }

    public func save(_ defaults: UserDefaults = .standard) { defaults.set(paths, forKey: IgnoreList.key) }

    public mutating func add(_ url: URL) {
        if !contains(url) { paths.append(url.path) }
    }

    public mutating func remove(_ path: String) { paths.removeAll { $0 == path } }

    /// MacPat's own log is always skipped.
    public func contains(_ url: URL, home: URL = FileManager.default.homeDirectoryForCurrentUser) -> Bool {
        let path = url.path
        return (paths + [ActionLog.folder(home: home).path]).contains { path == $0 || path.hasPrefix($0 + "/") }
    }
}
