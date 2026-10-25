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
        let rows = plan.steps.map { Entry.Row(command: $0.display, result: outcome.failure(for: $0).map { "failed: \($0)" } ?? "done") }
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
