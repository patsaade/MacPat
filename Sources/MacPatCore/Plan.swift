// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Patrick Saade

import CryptoKit
import Foundation

/// A labelled detail shown under a step, such as "Last used" or "Signed by".
public struct Fact: Hashable, Sendable, Codable {
    public let label: String
    public let value: String

    public init(_ label: String, _ value: String) {
        self.label = label
        self.value = value
    }
}

/// What a step does when it runs.
public enum Action: Hashable, Sendable {
    /// Move to the Trash as the user.
    case trash(URL)
    /// Move a root-owned item to the user's Trash through the admin prompt.
    case adminTrash(URL)
    case command(Command)
    /// Several actions in order, for example stop a service, then move its file.
    /// Stops at the first failure. Nested sequences are refused when run.
    case sequence([Action])
    /// Shown only. Pair it with a locked risk; the executor refuses it either way.
    case none
}

/// One thing a module would do, with the reasons. Every module's preview is a list of these.
public struct Step: Identifiable, Hashable, Sendable {
    public let id: String
    public var group: String
    public var title: String
    public var bytes: Int64
    public var risk: Risk
    public var reason: String
    public var facts: [Fact]
    public var action: Action
    /// Chosen when the scan finishes. Only safe steps should be.
    public var preselected: Bool
    /// When the file last changed, if the scan already knew. Not part of the plan fingerprint.
    public var modified: Date?

    public init(
        group: String, title: String, bytes: Int64 = 0, risk: Risk, reason: String, facts: [Fact] = [], action: Action,
        preselected: Bool? = nil, id: String? = nil, modified: Date? = nil
    ) {
        self.group = group
        self.title = title
        self.bytes = bytes
        self.risk = risk
        self.reason = reason
        self.facts = facts
        self.action = action
        self.preselected = preselected ?? (risk == .safe)
        self.modified = modified
        self.id = id ?? Step.key(action)
    }

    static func key(_ action: Action) -> String { action.display }

    public var url: URL? { action.url }
    public var needsAdmin: Bool { action.needsAdmin }
    /// The same step as shell lines, for "Show commands" and "Copy as script".
    public var display: String { action.display }
}

extension Action {
    /// The file the action is about: the first one in a sequence.
    public var url: URL? {
        switch self {
        case .trash(let url), .adminTrash(let url): url
        case .command: nil
        case .sequence(let all): all.lazy.compactMap(\.url).first
        case .none: nil
        }
    }

    public var needsAdmin: Bool {
        switch self {
        case .trash: false
        case .adminTrash: true
        case .command(let c): c.admin
        case .sequence(let all): all.contains(where: \.needsAdmin)
        case .none: false
        }
    }

    public var display: String {
        switch self {
        case .trash(let url): "mv -n \(Command.quoted(url.path)) ~/.Trash/"
        case .adminTrash(let url): "sudo mv -n \(Command.quoted(url.path)) ~/.Trash/"
        case .command(let c): c.display
        case .sequence(let all): all.map(\.display).joined(separator: "\n")
        case .none: "# shown only, nothing runs"
        }
    }
}

/// The chosen steps, frozen. The fingerprint ties a real run to the preview the user read.
public struct Plan: Sendable, Equatable {
    public let steps: [Step]
    public let fingerprint: String

    public init(_ steps: [Step]) {
        self.steps = steps
        fingerprint = Plan.fingerprint(steps)
    }

    public var bytes: Int64 { steps.reduce(0) { $0 + $1.bytes } }

    /// Hashes each step's action and risk, plus the file's device, inode, and type.
    /// A path swapped for a different file or a symlink changes it. New content inside a cache folder doesn't.
    static func fingerprint(_ steps: [Step]) -> String {
        var hash = SHA256()
        for step in steps.sorted(by: { $0.id < $1.id }) {
            var line = "\(step.id)\u{1F}\(step.display)\u{1F}\(step.risk.rawValue)"
            if let url = step.url {
                var info = stat()
                if lstat(url.path, &info) == 0 {
                    line += "\u{1F}\(info.st_dev):\(info.st_ino):\(info.st_mode & S_IFMT)"
                } else {
                    line += "\u{1F}missing"
                }
            }
            hash.update(data: Data((line + "\n").utf8))
        }
        return hash.finalize().map { String(format: "%02x", $0) }.joined()
    }

    /// Paste-able shell script. A record of the plan, not how MacPat runs it.
    public func script(date: Date = .now) -> String {
        var lines = [
            "#!/usr/bin/env sh", "# MacPat plan \(fingerprint.prefix(12)), \(date.formatted(.iso8601))",
            "# A record of the plan. Read it before you run any of it.", "set -eu",
        ]
        for group in Dictionary(grouping: steps, by: \.group).sorted(by: { $0.key < $1.key }) {
            lines.append("")
            lines.append("# \(group.key)")
            lines += group.value.map(\.display)
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// The plan as JSON, for people who want to diff or keep it.
    public func json() throws -> Data {
        struct Row: Encodable {
            let group, title, risk, reason, command: String
            let bytes: Int64
            let admin: Bool
            let facts: [Fact]
        }
        struct Doc: Encodable {
            let fingerprint: String
            let steps: [Row]
        }
        let rows = steps.map {
            Row(
                group: $0.group, title: $0.title, risk: $0.risk.rawValue, reason: $0.reason, command: $0.display, bytes: $0.bytes,
                admin: $0.needsAdmin, facts: $0.facts)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(Doc(fingerprint: fingerprint, steps: rows))
    }
}
