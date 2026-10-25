// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Patrick Saade

import Foundation
import MacPatCore
import PersistenceKit

/// Finds an app's files outside its bundle and turns them into a plan.
/// Exact bundle-ID matches are safe. Team-ID and name-only matches are review, and name-only is never preselected.
public struct LeftoverScanner: Sendable {
    public let app: AppInfo
    public let home: URL
    public var running: Set<String> = []
    public var launchItems: [LaunchItem] = []
    public var receipts: [String: Int] = [:]

    public init(app: AppInfo, home: URL) {
        self.app = app
        self.home = home
    }

    /// Library folders searched, by group name. All of them are Zones for Uninstall.
    static let userFolders: [(String, String)] = [
        ("Library/Application Support", "Support files"), ("Library/Caches", "Caches"), ("Library/Containers", "Sandbox containers"),
        ("Library/Group Containers", "Shared containers"), ("Library/Preferences", "Preferences"),
        ("Library/Preferences/ByHost", "Preferences"), ("Library/Saved Application State", "Saved window state"),
        ("Library/HTTPStorages", "Web storage"), ("Library/WebKit", "Web storage"), ("Library/Logs", "Logs"),
        ("Library/Cookies", "Cookies"), ("Library/Application Scripts", "Scripts"),
    ]
    static let systemFolders: [(String, String)] = [
        ("/Library/Application Support", "Support files (all users)"), ("/Library/Caches", "Caches (all users)"),
        ("/Library/Preferences", "Preferences (all users)"),
    ]

    public static func zones(home: URL) -> Zones {
        Zones(home: home, relativePaths: userFolders.map(\.0) + ["Library/LaunchAgents", "Applications"], refusesApple: true)
            .union(Zones(roots: [URL(filePath: "/Applications")], refusesApple: true))
    }

    enum Match { case exact, team, name }

    func match(_ name: String) -> Match? {
        let base = BundleName.base(name)
        guard !base.lowercased().hasPrefix("com.apple.") else { return nil }
        if let id = app.bundleID?.lowercased(), BundleName.isSpecific(id) {
            let b = base.lowercased()
            if b == id || b.hasPrefix(id + ".") { return .exact }
            if b.hasSuffix("." + id) { return .team }  // group containers: TEAMID.bundle.id, group.bundle.id
        }
        if let team = app.teamID, team.wholeMatch(of: /[A-Z0-9]{10}/) != nil, base.hasPrefix(team + ".") { return .team }
        if base.caseInsensitiveCompare(app.name) == .orderedSame { return .name }
        return nil
    }

    public func steps() -> [Step] {
        if app.isApple {
            return [
                Step(
                    group: "App", title: app.name, risk: .locked, reason: "Made by Apple or part of macOS. MacPat won't remove it.",
                    action: .trash(app.url))
            ]
        }
        var steps = [appStep()]
        let fm = FileManager.default
        for (folder, group) in Self.userFolders.map({ (home.appending(path: $0.0), $0.1) })
            + Self.systemFolders.map({ (URL(filePath: $0.0), $0.1) })
        {
            let system = !folder.path.hasPrefix(home.path + "/")
            for url in (try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? [] {
                guard let m = match(url.lastPathComponent) else { continue }
                let (risk, reason): (Risk, String) =
                    switch m {
                    case .exact: (.safe, "Named after the app's bundle ID, \(app.bundleID ?? "").")
                    case .team:
                        (.review, "Shared by apps from the same developer (Team ID \(app.teamID ?? "?")). Their other apps may use it.")
                    case .name: (.review, "Matches the app's name only. Make sure it isn't another app's.")
                    }
                steps.append(
                    Step(
                        group: group, title: url.lastPathComponent, bytes: TargetScanner.size(of: url), risk: risk, reason: reason,
                        facts: [Fact("Path", url.path)], action: system ? .adminTrash(url) : .trash(url), preselected: m == .exact))
            }
        }
        steps += launchSteps() + receiptSteps()
        var seen = Set<String>()
        steps = steps.filter { seen.insert($0.id).inserted }
        if isRunning {
            // A running app rewrites its files as you watch. Nothing moves until it quits.
            steps = steps.map {
                var s = $0; s.risk = .locked; s.preselected = false; return s
            }
        }
        return steps
    }

    public var isRunning: Bool {
        app.bundleID.map(running.contains) ?? false
    }

    func appStep() -> Step {
        let bundle = Bundle(url: app.url)
        let version = bundle?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        var facts = [Fact("Signed by", app.signature.summary)]
        if let version { facts.append(Fact("Version", version)) }
        if let id = app.bundleID { facts.append(Fact("Bundle ID", id)) }
        let userCanMove = FileManager.default.isDeletableFile(atPath: app.url.path)
        return Step(
            group: "App", title: app.name, bytes: TargetScanner.size(of: app.url), risk: isRunning ? .locked : .safe,
            reason: isRunning ? "\(app.name) is running. Quit it first, then scan again." : "The app itself.",
            facts: facts, action: userCanMove ? .trash(app.url) : .adminTrash(app.url))
    }

    /// Launch jobs whose program lives in the app, or whose label starts with its bundle ID.
    func launchSteps() -> [Step] {
        launchItems.compactMap { item -> Step? in
            let inside = item.program?.path.hasPrefix(app.url.path + "/") ?? false
            let named = app.bundleID.map { BundleName.isSpecific($0) && (item.label == $0 || item.label.hasPrefix($0 + ".")) } ?? false
            guard inside || named, item.place != .inApp, item.place != .apple,
                let bootout = try? Command.bootout(item.domain, label: item.label)
            else { return nil }
            let move: Action = item.place == .userAgent ? .trash(item.plist) : .adminTrash(item.plist)
            return Step(
                group: "Starts at login", title: item.label, risk: .safe,
                reason: inside ? "Runs a program inside \(app.name). It breaks once the app is gone." : "Named after the app's bundle ID.",
                facts: [Fact("Plist", item.plist.path)], action: .sequence((item.loaded ? [.command(bootout)] : []) + [move]),
                preselected: true, id: "launch:\(item.plist.path)")
        }
    }

    func receiptSteps() -> [Step] {
        receipts.sorted { $0.key < $1.key }.compactMap { id, count in
            guard (try? Command.pkgutilFiles(id)) != nil else { return nil }
            return Step(
                group: "Installer receipts", title: id, risk: .locked,
                reason:
                    "Installed by a package that listed \(count) files. MacPat moves only the files above. To drop the receipt: sudo pkgutil --forget \(id)",
                action: .none, preselected: false, id: "receipt:\(id)")
        }
    }
}

/// Library items named like a bundle ID that no installed app claims.
public struct OrphanScanner: Sendable {
    public let home: URL
    public let isInstalled: @Sendable (String) -> Bool

    public init(home: URL, isInstalled: @escaping @Sendable (String) -> Bool) {
        self.home = home
        self.isInstalled = isInstalled
    }

    static let folders = [
        "Library/Application Support", "Library/Caches", "Library/Containers", "Library/Preferences", "Library/Saved Application State",
        "Library/HTTPStorages", "Library/WebKit",
    ]

    static func bundleID(_ name: String) -> String? {
        let base = BundleName.base(name)
        guard base.wholeMatch(of: /[A-Za-z0-9-]+\.[A-Za-z0-9-]+\.[A-Za-z0-9.-]+/) != nil, !base.lowercased().hasPrefix("com.apple.") else {
            return nil
        }
        return base
    }

    public func steps() -> [Step] {
        let fm = FileManager.default
        return Self.folders.flatMap { rel -> [Step] in
            let dir = home.appending(path: rel)
            return ((try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []).compactMap { url in
                guard let id = Self.bundleID(url.lastPathComponent), !isInstalled(id) else { return nil }
                return Step(
                    group: "Orphans: \(rel.replacingOccurrences(of: "Library/", with: ""))", title: url.lastPathComponent,
                    bytes: TargetScanner.size(of: url), risk: .review,
                    reason:
                        "No installed app has the bundle ID \(id). It may be from a deleted app, or from a helper or tool macOS doesn't list.",
                    facts: (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate).map {
                        [Fact("Modified", $0.formatted(.relative(presentation: .named, unitsStyle: .wide)))]
                    } ?? [],
                    action: .trash(url), preselected: false)
            }
        }
    }
}
