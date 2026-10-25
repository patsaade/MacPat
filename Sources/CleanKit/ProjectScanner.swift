// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Patrick Saade

import Foundation
import MacPatCore

/// Finds build folders inside a folder the user picked. A folder counts only when its
/// project manifest sits next to it, and only when nobody touched it for two weeks.
public struct ProjectScanner: Sendable {
    public let root: URL
    public var maxDepth = 6
    public var minAgeDays = 14

    public init(root: URL) { self.root = root }

    /// The zone a picked folder grants. Empty when the folder is home, a system folder, or too broad.
    public var zones: Zones { Zones(roots: [root]) }

    struct Kind {
        let folder: String
        let manifests: [String]
        let rebuild: String
    }

    static let kinds = [
        Kind(folder: "node_modules", manifests: ["package.json"], rebuild: "npm install (or your package manager)"),
        Kind(folder: "target", manifests: ["Cargo.toml"], rebuild: "cargo build"),
        Kind(folder: ".build", manifests: ["Package.swift"], rebuild: "swift build"),
        Kind(folder: "build", manifests: ["build.gradle", "build.gradle.kts"], rebuild: "gradle build"),
        Kind(folder: "Pods", manifests: ["Podfile"], rebuild: "pod install"),
        Kind(folder: ".next", manifests: ["next.config.js", "next.config.mjs", "next.config.ts"], rebuild: "next build"),
    ]

    public func steps(now: Date = .now) -> [Step] {
        let zones = zones
        guard !zones.roots.isEmpty else { return [] }
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.isDirectoryKey, .isSymbolicLinkKey, .contentModificationDateKey]
        guard let walk = fm.enumerator(at: zones.roots[0], includingPropertiesForKeys: keys, errorHandler: { _, _ in true }) else {
            return []
        }
        var steps: [Step] = []
        for case let url as URL in walk {
            let values = try? url.resourceValues(forKeys: Set(keys))
            guard values?.isDirectory == true, values?.isSymbolicLink != true else { continue }
            if walk.level > maxDepth || url.lastPathComponent == "Library" {
                walk.skipDescendants()
                continue
            }
            let name = url.lastPathComponent
            let parent = url.deletingLastPathComponent()
            guard let kind = Self.kinds.first(where: { $0.folder == name }) else {
                if name.hasPrefix(".") { walk.skipDescendants() }
                continue
            }
            walk.skipDescendants()
            guard kind.manifests.contains(where: { fm.fileExists(atPath: parent.appending(path: $0).path) }) else { continue }
            let modified = values?.contentModificationDate ?? now
            guard now.timeIntervalSince(modified) >= Double(minAgeDays) * 86_400, let valid = try? zones.validate(url) else { continue }
            steps.append(
                Step(
                    group: "Projects: build folders", title: "\(parent.lastPathComponent)/\(name)", bytes: TargetScanner.size(of: valid),
                    risk: .review, reason: "Rebuilt from the project's manifest. Your source files are not touched.",
                    facts: [
                        Fact("Comes back", kind.rebuild),
                        Fact("Last touched", modified.formatted(.relative(presentation: .named, unitsStyle: .wide))),
                    ],
                    action: .trash(valid), preselected: false))
        }
        return steps
    }
}
