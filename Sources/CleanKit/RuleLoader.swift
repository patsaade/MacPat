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
    }

    public static func load(from directory: URL, home: URL, zones: Zones) throws -> [Target] {
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
            guard !rule.paths.isEmpty else { throw bad("no paths") }
            let paths = try rule.paths.map { raw -> URL in
                guard raw.hasPrefix("~/") else { throw bad("path must start with ~/: \(raw)") }
                let url = home.appending(path: String(raw.dropFirst(2)))
                guard zones.contains(url) else { throw bad("path outside the safe zones: \(raw)") }
                return url
            }
            return Target(id: rule.id, name: rule.name, summary: rule.summary, risk: rule.risk, paths: paths)
        }
    }

    public static var bundledDirectory: URL { Bundle.module.resourceURL!.appending(path: "Rules") }
}
