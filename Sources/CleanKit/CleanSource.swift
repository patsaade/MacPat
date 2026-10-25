// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Patrick Saade

import Foundation
import MacPatCore

/// Turns rules, and an optional projects folder, into plan steps with reasons.
public struct CleanSource: Sendable {
    public let targets: [Target]
    public let zones: Zones
    public let system: Zones
    public let home: URL
    public let projects: URL?

    public init(targets: [Target], zones: Zones, system: Zones = .system, home: URL, projects: URL? = nil) {
        self.targets = targets
        self.zones = zones
        self.system = system
        self.home = home
        self.projects = projects
    }

    public func steps(now: Date = .now) -> [Step] {
        var out = targets.flatMap { steps(for: $0, now: now) }
        if let projects { out += ProjectScanner(root: projects).steps(now: now) }
        var seen = Set<String>()
        return out.filter { seen.insert($0.id).inserted }
    }

    /// One batch from `stream`: the target's position, its steps, and how far along the scan is.
    public typealias Batch = @Sendable (_ index: Int, _ steps: [Step], _ done: Int, _ total: Int) -> Void

    /// Scans four targets at a time and reports each as it finishes. Folders macOS guards come last,
    /// so a permission prompt never holds up the rest.
    public func stream(now: Date = .now, _ batch: @escaping Batch) async {
        let total = targets.count + (projects == nil ? 0 : 1)
        let order = targets.indices.sorted { a, b in
            let (x, y) = (guarded(targets[a]), guarded(targets[b]))
            return x != y ? !x : a < b
        }
        await withTaskGroup(of: (Int, [Step]).self) { group in
            var next = order.makeIterator()
            var done = 0
            func launch() {
                guard !Task.isCancelled, let i = next.next() else { return }
                group.addTask { (i, self.steps(for: self.targets[i], now: now)) }
            }
            for _ in 0..<4 { launch() }
            while let (i, steps) = await group.next() {
                done += 1
                batch(i, steps, done, total)
                launch()
            }
        }
        if let projects, !Task.isCancelled {
            batch(targets.count, ProjectScanner(root: projects).steps(now: now), total, total)
        }
    }

    /// Folders behind macOS privacy checks. Listing one can wait on a prompt.
    static let guardedFolders = ["/Library/Mail", "/Library/Safari", "/MobileSync", "/Downloads", "/Library/Messages"]

    func guarded(_ target: Target) -> Bool {
        target.paths.contains { path in Self.guardedFolders.contains { path.path.contains($0) } }
    }

    func steps(for target: Target, now: Date) -> [Step] {
        var out: [Step] = []
        let group = "\(target.group): \(target.name)"
        let preselected = target.preselect ?? (target.risk == .safe)
        var base = [Fact("Comes back", target.regenerates)].filter { !$0.value.isEmpty }
        if let command = target.command {
            guard applies(command) else { return [] }
            return [
                Step(
                    group: group, title: target.summary, risk: target.risk, reason: target.reason, facts: base,
                    action: .command(command), preselected: preselected)
            ]
        }
        if target.system { base.append(Fact("Needs", "Admin. The file is owned by root.")) }
        let (items, unreadable) = TargetScanner(zones: target.system ? system : zones).report(target, now: now)
        for path in unreadable {
            out.append(
                Step(
                    group: "Needs access", title: target.name, risk: .locked,
                    reason: "macOS didn't let MacPat read this folder. Allow MacPat under Full Disk Access, then Scan again.",
                    facts: [Fact("Folder", path.path)], action: .none, preselected: false, id: "needs-access:\(path.path)"))
        }
        for item in items {
            out.append(
                Step(
                    group: group, title: item.url.lastPathComponent, bytes: item.bytes, risk: target.risk, reason: target.reason,
                    facts: Facts.modified(item.modified, now: now) + Facts.extra(target.details, item.url) + base,
                    action: target.system ? .adminTrash(item.url) : .trash(item.url), preselected: preselected,
                    modified: item.modified))
        }
        return out
    }

    func applies(_ command: Command) -> Bool {
        command != .deleteUnavailableSimulators()
            || FileManager.default.fileExists(atPath: home.appending(path: "Library/Developer/CoreSimulator/Devices").path)
    }
}

enum Facts {
    static func modified(_ date: Date?, now: Date) -> [Fact] {
        guard let date else { return [] }
        return [Fact("Modified", date.formatted(.relative(presentation: .named, unitsStyle: .wide)))]
    }

    static func extra(_ details: String?, _ url: URL) -> [Fact] {
        switch details {
        case "download-source": whereFrom(url).map { [Fact("Downloaded from", $0)] } ?? []
        case "device-backup": backup(url)
        default: []
        }
    }

    /// The download source Safari and friends record on the file.
    static func whereFrom(_ url: URL) -> String? {
        let name = "com.apple.metadata:kMDItemWhereFroms"
        let size = getxattr(url.path, name, nil, 0, 0, XATTR_NOFOLLOW)
        guard size > 0, size < 65_536 else { return nil }
        var data = Data(count: size)
        let read = data.withUnsafeMutableBytes { getxattr(url.path, name, $0.baseAddress, size, 0, XATTR_NOFOLLOW) }
        guard read == size, let list = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String] else { return nil }
        return list.first
    }

    static func backup(_ url: URL) -> [Fact] {
        guard let data = try? Data(contentsOf: url.appending(path: "Info.plist")),
            let info = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return [] }
        var facts: [Fact] = []
        if let name = info["Device Name"] as? String { facts.append(Fact("Device", name)) }
        if let date = info["Last Backup Date"] as? Date {
            facts.append(Fact("Backed up", date.formatted(date: .abbreviated, time: .shortened)))
        }
        return facts
    }
}
