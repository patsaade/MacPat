// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Patrick Saade

import Foundation

public enum SafetyError: Error, Equatable {
    case invalidPath
    case outsideZones
}

/// The only places MacPat may delete from. Everything else is refused.
public struct Zones: Sendable {
    public let roots: [URL]

    /// Zones live under the home folder. A root that resolves outside it
    /// (a symlink, say) is dropped, so a swapped link can't widen the list.
    public init(home: URL, relativePaths: [String] = Zones.standardPaths) {
        let home = home.resolvingSymlinksInPath()
        let homeParts = home.pathComponents
        roots = relativePaths.compactMap { rel in
            let root = home.appending(path: rel).resolvingSymlinksInPath()
            let parts = root.pathComponents
            return parts.count > homeParts.count && parts.starts(with: homeParts) ? root : nil
        }
    }

    public static let standardPaths = [
        "Library/Caches",
        "Library/Logs",
        "Library/Developer/Xcode/DerivedData",
        ".npm/_cacache",
    ]

    /// True for a zone root or anything under it. Use to vet rule paths.
    public func contains(_ url: URL) -> Bool {
        guard url.isFileURL, !url.pathComponents.contains("..") else { return false }
        let parts = url.resolvingSymlinksInPath().pathComponents
        return roots.contains { parts.starts(with: $0.pathComponents) }
    }

    /// Returns the item path to act on, or throws. The last component is
    /// never resolved, so a symlink is handled as a link, not followed.
    /// The path must sit strictly below a zone root. Zone roots are refused.
    public func validate(_ url: URL) throws -> URL {
        let name = url.lastPathComponent
        guard url.isFileURL, !name.isEmpty, name != "/",
            !url.pathComponents.contains(where: { $0 == ".." || $0 == "." })
        else { throw SafetyError.invalidPath }
        let item = url.deletingLastPathComponent().resolvingSymlinksInPath().appending(path: name)
        let parts = item.pathComponents
        guard roots.contains(where: { parts.count > $0.pathComponents.count && parts.starts(with: $0.pathComponents) })
        else { throw SafetyError.outsideZones }
        return item
    }
}
