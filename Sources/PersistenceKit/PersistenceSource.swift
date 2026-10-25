// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Patrick Saade

import Foundation
import MacPatCore

/// What a persistence plan does to each launchd job.
public enum PersistenceMode: String, Sendable, CaseIterable, Identifiable {
    case disable = "Disable"
    case remove = "Remove"
    case enable = "Re-enable"
    public var id: String { rawValue }

    var help: String {
        switch self {
        case .disable: "Stops the job and keeps it from starting. The file stays. Re-enable undoes it."
        case .remove: "Stops the job and moves its file to the Trash."
        case .enable: "Lists jobs that are disabled, so you can turn them back on."
        }
    }
}

public struct PersistenceSource: Sendable {
    public var mode: PersistenceMode
    public var includeApple: Bool
    public var deepScan: String?
    let home: URL
    let runner: Runner

    public init(mode: PersistenceMode, includeApple: Bool = false, deepScan: String? = nil, home: URL, runner: Runner = .live) {
        self.mode = mode
        self.includeApple = includeApple
        self.deepScan = deepScan
        self.home = home
        self.runner = runner
    }

    /// Where a Remove step may move from as the user.
    public static func zones(home: URL) -> Zones {
        Zones(home: home, relativePaths: ["Library/LaunchAgents", "Library/Spotlight", "Library/QuickLook"])
    }

    public func steps() -> [Step] {
        let apps = AppIndex.scan(AppIndex.folders(home: home))
        let items = LaunchScanner.scan(home: home, includeApple: includeApple, apps: apps, runner: runner)
        let teams = Dictionary(apps.compactMap { app in app.teamID.map { ($0, app.name) } }, uniquingKeysWith: { a, _ in a })
        var steps = items.compactMap { step(for: $0, teams: teams) }
        if mode == .remove {
            steps += helpers(items) + startupItems() + plugins()
        }
        steps +=
            OtherPlaces.loginHooks(home: home) + OtherPlaces.cron(runner) + OtherPlaces.profiles(runner)
            + OtherPlaces.systemExtensions(runner) + OtherPlaces.kernelAndAuth() + OtherPlaces.shellLines(home: home)
        if let deepScan { steps += OtherPlaces.backgroundItems(deepScan) }
        return steps
    }

    func facts(_ item: LaunchItem, owner: String?) -> [Fact] {
        var facts = [Fact("Label", item.label), Fact("Program", item.program.map(\.path) ?? "none listed")]
        facts.append(Fact("Signed by", item.signature.summary))
        if let owner { facts.append(Fact("Owner", owner)) }
        if !item.triggers.isEmpty { facts.append(Fact("Starts", item.triggers.joined(separator: ", "))) }
        facts.append(
            Fact("State", [item.loaded ? "loaded" : "not loaded", item.disabled ? "disabled" : "enabled"].joined(separator: ", ")))
        if !item.oddities.isEmpty { facts.append(Fact("Unusual", item.oddities.joined(separator: "; "))) }
        if let date = item.modified { facts.append(Fact("Plist changed", date.formatted(date: .abbreviated, time: .shortened))) }
        return facts
    }

    func step(for item: LaunchItem, teams: [String: String]) -> Step? {
        let owner = item.app.map { $0.deletingPathExtension().lastPathComponent } ?? item.signature.teamID.flatMap { teams[$0] }
        let facts = facts(item, owner: owner)
        let group = "\(item.place.rawValue)"
        let lockedReason: String? =
            switch item.place {
            case .apple: "Part of macOS. Shown so you can see it."
            case .inApp:
                "Registered by its app through macOS. Turn it off in System Settings, General, Login Items & Extensions, or delete the app."
            default: nil
            }
        if let lockedReason {
            guard mode != .enable else { return nil }
            return Step(
                group: group, title: item.label, risk: .locked, reason: lockedReason, facts: facts, action: .none,
                preselected: false, id: "launch:\(item.plist.path)")
        }
        guard let bootout = try? Command.bootout(item.domain, label: item.label),
            let disable = try? Command.disable(item.domain, label: item.label),
            let enable = try? Command.enable(item.domain, label: item.label)
        else { return nil }
        let (risk, reason) = verdict(item, owner: owner)
        let stop: [Action] = item.loaded ? [.command(bootout)] : []
        let action: Action
        switch mode {
        case .disable:
            guard !item.disabled else { return nil }
            action = .sequence([.command(disable)] + stop)
        case .remove:
            let move: Action = item.place == .userAgent ? .trash(item.plist) : .adminTrash(item.plist)
            action = .sequence(stop + [move])
        case .enable:
            guard item.disabled else { return nil }
            return Step(
                group: group, title: item.label, risk: .safe, reason: "Lets it start again at next login or boot.", facts: facts,
                action: .command(enable), preselected: false, id: "launch:\(item.plist.path)")
        }
        return Step(
            group: group, title: item.label, risk: risk, reason: reason, facts: facts, action: action, preselected: risk == .safe,
            id: "launch:\(item.plist.path)")
    }

    func verdict(_ item: LaunchItem, owner: String?) -> (Risk, String) {
        if item.missing, item.program != nil {
            return (.safe, "Orphan. Its program is gone, so it only fails each time it starts.")
        }
        if !item.oddities.isEmpty {
            return (
                .review, "Unusual: \(item.oddities.joined(separator: ", ")). Not proof of harm. Find out what it is before you keep it."
            )
        }
        return (
            .review,
            "Stops \(owner ?? "its app") from starting this \(item.triggers.first ?? "in the background"). The app may lose a feature."
        )
    }

    /// Privileged helpers. One no daemon points at is an orphan.
    func helpers(_ items: [LaunchItem]) -> [Step] {
        let dir = URL(filePath: "/Library/PrivilegedHelperTools")
        var used = Set(items.compactMap { $0.program?.path } + items.map { dir.appending(path: $0.label).path })
        let fm = FileManager.default
        let raw = ((try? fm.contentsOfDirectory(at: URL(filePath: "/Library/LaunchDaemons"), includingPropertiesForKeys: nil)) ?? [])
            .compactMap { try? String(contentsOf: $0, encoding: .utf8) }.joined()
        for helper in (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        where raw.contains(helper.lastPathComponent) {
            used.insert(helper.path)
        }
        return ((try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []).map { url in
            let orphan = !used.contains(url.path)
            return Step(
                group: "Privileged helpers", title: url.lastPathComponent, bytes: TargetScanner.size(of: url),
                risk: orphan ? .safe : .review,
                reason: orphan
                    ? "Orphan. No daemon mentions it any more."
                    : "A daemon still runs this as root. Remove that daemon in the same plan.",
                facts: [Fact("Signed by", Signing.check(url).summary)], action: .adminTrash(url), preselected: orphan)
        }
    }

    func startupItems() -> [Step] {
        let dir = URL(filePath: "/Library/StartupItems")
        return ((try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []).map {
            Step(
                group: "Startup items", title: $0.lastPathComponent, risk: .safe,
                reason: "macOS stopped running startup items years ago. This one was left behind.", action: .adminTrash($0))
        }
    }

    func plugins() -> [Step] {
        let places: [(String, String, Bool)] = [
            ("Library/Spotlight", "mdimporter", false), ("Library/QuickLook", "qlgenerator", false),
            ("/Library/Spotlight", "mdimporter", true), ("/Library/QuickLook", "qlgenerator", true),
        ]
        return places.flatMap { path, ext, system -> [Step] in
            let dir = system ? URL(filePath: path) : home.appending(path: path)
            let found = ((try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []).filter {
                $0.pathExtension == ext
            }
            return found.map {
                Step(
                    group: ext == "mdimporter" ? "Spotlight importers" : "Quick Look plugins", title: $0.lastPathComponent,
                    bytes: TargetScanner.size(of: $0), risk: .review,
                    reason: "Loaded by macOS to read one kind of file. Old ones do nothing.",
                    facts: [Fact("Signed by", Signing.check($0).summary)], action: system ? .adminTrash($0) : .trash($0), preselected: false
                )
            }
        }
    }
}
