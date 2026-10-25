// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Patrick Saade

import Foundation
import MacPatCore

public enum RuleError: Error, Equatable {
    case invalid(file: String, reason: String)
}

/// Reads rule files. Fails closed: one bad rule rejects the whole set.
public enum RuleLoader {
    private struct Rule: Decodable {
        let id: String
        let name: String
        let summary: String
        let risk: Risk
        let paths: [String]
        var group: String?
        var reason: String?
        var regenerates: String?
        var match: [String]?
        var exclude: [String]?
        var minAgeDays: Int?
        var scope: String?
        var preselect: Bool?
        var command: String?
        var details: String?
    }

    /// Extra facts a rule may ask for, by name.
    static let details: Set<String> = ["download-source", "device-backup"]

    /// The commands a rule may name. Nothing else can be run from a rule.
    static let commands: [String: Command] = ["simctl-delete-unavailable": .deleteUnavailableSimulators()]

    public static func load(from directory: URL, home: URL, zones: Zones, system: Zones = .system) throws -> [Target] {
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        var seen = Set<String>()
        return try files.map { file in
            func bad(_ reason: String) -> RuleError { .invalid(file: file.lastPathComponent, reason: reason) }
            let rule: Rule
            do { rule = try JSONDecoder().decode(Rule.self, from: Data(contentsOf: file)) } catch { throw bad("unreadable: \(error)") }
            guard rule.id.wholeMatch(of: /[a-z0-9-]{1,40}/) != nil else { throw bad("id must be 1-40 chars of a-z, 0-9, -") }
            guard seen.insert(rule.id).inserted else { throw bad("duplicate id") }
            guard !rule.name.isEmpty, rule.name.count <= 60, !rule.summary.isEmpty, rule.summary.count <= 120
            else { throw bad("name or summary missing or too long") }
            guard rule.risk != .locked else { throw bad("rules can't be locked") }
            let isSystem: Bool
            switch rule.scope ?? "user" {
            case "user": isSystem = false
            case "system": isSystem = true
            default: throw bad("scope must be user or system")
            }
            let command = try rule.command.map { name -> Command in
                guard let c = commands[name] else { throw bad("unknown command: \(name)") }
                return c
            }
            guard !rule.paths.isEmpty || command != nil else { throw bad("no paths") }
            guard rule.risk == .safe || rule.preselect != true else { throw bad("review rules can't be preselected") }
            guard rule.details.map(details.contains) ?? true else { throw bad("unknown details: \(rule.details ?? "")") }
            guard (rule.minAgeDays ?? 0) >= 0, (rule.minAgeDays ?? 0) <= 3650 else { throw bad("minAgeDays out of range") }
            for glob in (rule.match ?? []) + (rule.exclude ?? []) where glob.isEmpty || glob.contains("/") {
                throw bad("globs match names, not paths: \(glob)")
            }
            let paths = try rule.paths.map { raw -> URL in
                if isSystem {
                    let url = URL(filePath: raw)
                    guard raw.hasPrefix("/"), system.contains(url) else { throw bad("path outside the system zones: \(raw)") }
                    return url
                }
                guard raw.hasPrefix("~/") else { throw bad("path must start with ~/: \(raw)") }
                let url = home.appending(path: String(raw.dropFirst(2)))
                guard zones.contains(url) else { throw bad("path outside the safe zones: \(raw)") }
                return url
            }
            var target = Target(id: rule.id, name: rule.name, summary: rule.summary, risk: rule.risk, paths: paths)
            target.group = rule.group ?? "Other"
            target.reason = rule.reason ?? rule.summary
            target.regenerates = rule.regenerates ?? ""
            target.match = rule.match ?? []
            target.exclude = rule.exclude ?? []
            target.minAgeDays = rule.minAgeDays ?? 0
            target.system = isSystem
            target.preselect = rule.preselect
            target.command = command
            target.details = rule.details
            return target
        }
    }

    public static var bundledDirectory: URL { Bundle.module.resourceURL!.appending(path: "Rules") }
}
