// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Patrick Saade

import Foundation

public enum SafetyError: Error, Equatable, CustomStringConvertible {
    case invalidPath
    case outsideZones
    case protectedPath
    case locked
    case badArgument(String)
    case planChanged

    public var description: String {
        switch self {
        case .invalidPath: "The path is empty or has . or .. in it."
        case .outsideZones: "Outside the folders MacPat may touch."
        case .protectedPath: "A protected system or Apple path."
        case .locked: "Locked. MacPat won't touch this."
        case .badArgument(let arg): "Failed the allowlist check: \(arg)"
        case .planChanged: "The plan changed since the preview. Preview again."
        }
    }
}

/// The only places MacPat may delete from. Everything else is refused.
public struct Zones: Sendable {
    public let roots: [URL]
    /// System zones refuse `com.apple.*` items, so Apple's own files stay put.
    public let refusesApple: Bool

    /// Zones under the home folder. A root that resolves outside it
    /// (a symlink, say) is dropped, so a swapped link can't widen the list.
    /// A root that is itself a symlink, or sits behind one, is dropped too, so `~/Movies -> ~/Library` can't widen it.
    public init(home: URL, relativePaths: [String] = Zones.standardPaths, refusesApple: Bool = false) {
        let home = home.resolvingSymlinksInPath()
        let homeParts = home.pathComponents
        roots = relativePaths.compactMap { rel in
            let literal = home.appending(path: rel).standardizedFileURL
            let root = literal.resolvingSymlinksInPath()
            let parts = root.pathComponents
            return parts.count > homeParts.count && parts.starts(with: homeParts) && root.path == literal.path
                && !Zones.isInsideProtected(root) ? root : nil
        }
        self.refusesApple = refusesApple
    }

    /// Absolute zones. Broad or protected roots are dropped. Items inside a protected path are refused at validation.
    public init(roots: [URL], refusesApple: Bool = false) {
        self.roots = roots.filter(\.isFileURL).map { $0.resolvingSymlinksInPath() }.filter { !Zones.isUnsafeRoot($0) }
        self.refusesApple = refusesApple
    }

    /// Both sets of roots. Used when one plan spans rule folders and a folder the user picked.
    public func union(_ other: Zones) -> Zones {
        Zones(roots: roots + other.roots, refusesApple: refusesApple || other.refusesApple)
    }

    /// Where Clean rules may point. Rule paths outside these fail to load.
    public static let standardPaths = [
        "Library/Caches",
        "Library/Logs",
        "Library/Developer/Xcode/DerivedData",
        "Library/Developer/Xcode/Archives",
        "Library/Developer/Xcode/iOS DeviceSupport",
        "Library/Developer/Xcode/watchOS DeviceSupport",
        "Library/Developer/Xcode/UserData/Previews",
        "Library/Developer/CoreSimulator/Caches",
        "Library/Application Support/MobileSync/Backup",
        "Library/Containers/com.apple.mail/Data/Library/Mail Downloads",
        "Downloads",
        ".npm/_cacache",
        ".bun/install/cache",
        ".cargo/registry/cache",
        ".gradle/caches",
        ".m2/repository",
    ]

    /// Folders admin steps may move from. Items are still checked against `protectedPaths`.
    public static let systemPaths = [
        "/Library/Caches", "/Library/Logs", "/Library/LaunchAgents", "/Library/LaunchDaemons",
        "/Library/PrivilegedHelperTools", "/Library/StartupItems", "/Library/Spotlight", "/Library/QuickLook",
        "/Library/Application Support", "/Library/Preferences", "/Applications",
    ]

    public static var system: Zones { Zones(roots: systemPaths.map { URL(filePath: $0) }, refusesApple: true) }

    /// Never an item, and nothing inside them is either.
    static let protectedPaths = [
        "/System", "/usr", "/bin", "/sbin", "/private/etc", "/private/var/db", "/Library/Apple",
        "/Library/Application Support/Apple", "/Library/Preferences/SystemConfiguration", "/Library/Security",
        "/Library/Extensions", "/Library/SystemExtensions", "/Applications/Utilities", "/Applications/Safari.app",
    ]
    /// Too broad to be a root.
    static let broadPaths = ["/", "/Users", "/Library", "/Volumes", "/private", "/private/var", "/opt", "/cores"]

    static func isInsideProtected(_ url: URL) -> Bool {
        let path = url.standardizedFileURL.path
        return protectedPaths.contains { path == $0 || path.hasPrefix($0 + "/") }
    }

    static func isUnsafeRoot(_ url: URL) -> Bool {
        let path = url.standardizedFileURL.path
        let home = FileManager.default.homeDirectoryForCurrentUser.resolvingSymlinksInPath().path
        return broadPaths.contains(path) || path == home || isInsideProtected(url)
    }

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
            !url.pathComponents.contains(where: { $0 == ".." || $0 == "." }),
            !url.path.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) })
        else { throw SafetyError.invalidPath }
        let item = url.deletingLastPathComponent().resolvingSymlinksInPath().appending(path: name)
        let parts = item.pathComponents
        guard roots.contains(where: { parts.count > $0.pathComponents.count && parts.starts(with: $0.pathComponents) })
        else { throw SafetyError.outsideZones }
        guard !Zones.isInsideProtected(item), !(refusesApple && name.lowercased().hasPrefix("com.apple."))
        else { throw SafetyError.protectedPath }
        return item
    }
}
