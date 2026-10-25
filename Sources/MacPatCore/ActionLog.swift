// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Patrick Saade

import Foundation

/// A local record of every real run: one JSON line per run. It never leaves the Mac.
public struct ActionLog: Sendable {
    public let url: URL

    public init(url: URL) { self.url = url }

    public static func standard(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> ActionLog {
        ActionLog(url: folder(home: home).appending(path: "actions.jsonl"))
    }

    public static func folder(home: URL) -> URL { home.appending(path: "Library/Logs/MacPat") }

    struct Entry: Codable {
        struct Row: Codable {
            let command: String
            let result: String
        }
        let date: Date
        let fingerprint: String
        let steps: [Row]
    }

    public func append(_ plan: Plan, _ outcome: Outcome) {
        // A stopped run lists what it never reached as "not run", so the log never claims a move that didn't happen.
        let rows = plan.steps.map { step in
            Entry.Row(
                command: step.display,
                result: outcome.notRun.contains(step.id) ? "not run" : outcome.failure(for: step).map { "failed: \($0)" } ?? "done")
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard var line = try? encoder.encode(Entry(date: .now, fingerprint: plan.fingerprint, steps: rows)) else { return }
        line.append(0x0A)
        let fm = FileManager.default
        try? fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if !fm.fileExists(atPath: url.path) { fm.createFile(atPath: url.path, contents: nil, attributes: [.posixPermissions: 0o600]) }
        guard let handle = try? FileHandle(forWritingTo: url) else { return }
        defer { try? handle.close() }
        _ = try? handle.seekToEnd()
        try? handle.write(contentsOf: line)
    }
}
