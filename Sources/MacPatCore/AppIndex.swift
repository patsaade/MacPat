// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Patrick Saade

import Foundation

/// One installed app, with who signed it.
public struct AppInfo: Sendable, Hashable, Identifiable {
    public let url: URL
    public let name: String
    public let bundleID: String?
    public let signature: Signature
    public var id: URL { url }

    public init(url: URL, name: String, bundleID: String?, signature: Signature) {
        self.url = url
        self.name = name
        self.bundleID = bundleID
        self.signature = signature
    }

    public var teamID: String? { signature.teamID }
    /// Shipped by Apple, or part of macOS. Never uninstalled.
    public var isApple: Bool {
        let id = bundleID?.lowercased() ?? ""
        return signature.kind == .apple || id == "com.apple" || id.hasPrefix("com.apple.")
    }
}

/// The apps in the usual folders. Read-only.
public enum AppIndex {
    public static func folders(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> [URL] {
        [URL(filePath: "/Applications"), URL(filePath: "/Applications/Utilities"), home.appending(path: "Applications")]
    }

    public static func info(_ url: URL) -> AppInfo {
        let bundle = Bundle(url: url)
        let name =
            (bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String) ?? url.deletingPathExtension().lastPathComponent
        return AppInfo(url: url, name: name, bundleID: bundle?.bundleIdentifier, signature: Signing.check(url))
    }

    public static func scan(_ folders: [URL] = folders()) -> [AppInfo] {
        let fm = FileManager.default
        let urls = folders.flatMap { dir in
            ((try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []).filter { $0.pathExtension == "app" }
        }
        return urls.map(info).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
