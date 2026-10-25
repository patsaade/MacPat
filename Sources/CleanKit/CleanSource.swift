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
        var out: [Step] = []
        for target in targets {
            let group = "\(target.group): \(target.name)"
            let preselected = target.preselect ?? (target.risk == .safe)
            var base = [Fact("Comes back", target.regenerates)].filter { !$0.value.isEmpty }
            if let command = target.command {
                guard applies(command) else { continue }
                out.append(
                    Step(
                        group: group, title: target.summary, risk: target.risk, reason: target.reason, facts: base,
                        action: .command(command), preselected: preselected))
                continue
            }
            if target.system { base.append(Fact("Needs", "Admin. The file is owned by root.")) }
            for item in TargetScanner(zones: target.system ? system : zones).scan(target, now: now) {
                out.append(
                    Step(
                        group: group, title: item.url.lastPathComponent, bytes: item.bytes, risk: target.risk, reason: target.reason,
                        facts: Facts.modified(item.url, now: now) + Facts.extra(target.details, item.url) + base,
                        action: target.system ? .adminTrash(item.url) : .trash(item.url), preselected: preselected))
            }
        }
        if let projects { out += ProjectScanner(root: projects).steps(now: now) }
        var seen = Set<String>()
        return out.filter { seen.insert($0.id).inserted }
    }

    func applies(_ command: Command) -> Bool {
        command != .deleteUnavailableSimulators()
            || FileManager.default.fileExists(atPath: home.appending(path: "Library/Developer/CoreSimulator/Devices").path)
    }
}

enum Facts {
    static func modified(_ url: URL, now: Date) -> [Fact] {
        guard let date = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate else { return [] }
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
