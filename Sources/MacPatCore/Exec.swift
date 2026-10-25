// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Patrick Saade

import Foundation

/// Every program MacPat may run, by absolute path. Nothing is looked up on PATH.
public enum Tool: String, Sendable, CaseIterable, Codable {
    case launchctl = "/bin/launchctl"
    case mv = "/bin/mv"
    case pkgutil = "/usr/sbin/pkgutil"
    case systemextensionsctl = "/usr/bin/systemextensionsctl"
    case profiles = "/usr/bin/profiles"
    case tmutil = "/usr/bin/tmutil"
    case crontab = "/usr/bin/crontab"
    case xcrun = "/usr/bin/xcrun"
    case qlmanage = "/usr/bin/qlmanage"
    case dscacheutil = "/usr/bin/dscacheutil"
    case killall = "/usr/bin/killall"
    case mdutil = "/usr/bin/mdutil"
    case sfltool = "/usr/bin/sfltool"
    case lsregister = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
}

/// One allowlisted command: a fixed program and fixed arguments.
/// The init is private. The factories below are the whole list, and each checks its inputs.
public struct Command: Hashable, Sendable {
    public let tool: Tool
    public let args: [String]
    /// Runs through the macOS admin prompt.
    public let admin: Bool

    private init(_ tool: Tool, _ args: [String], admin: Bool = false) {
        self.tool = tool
        self.args = args
        self.admin = admin
    }

    // MARK: Argument checks

    static func label(_ s: String) throws -> String {
        guard s.wholeMatch(of: /[A-Za-z0-9][A-Za-z0-9._-]{0,200}/) != nil else { throw SafetyError.badArgument(s) }
        return s
    }

    static func path(_ url: URL) throws -> String {
        let p = url.path
        guard url.isFileURL, p.hasPrefix("/"), !url.pathComponents.contains(where: { $0 == ".." || $0 == "." }),
            !p.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) })
        else { throw SafetyError.badArgument(p) }
        return p
    }

    /// `gui/<uid>` for a user's agents, `system` for daemons.
    public enum Domain: Hashable, Sendable {
        case gui(uid_t)
        case system

        var target: String {
            switch self {
            case .gui(let uid): "gui/\(uid)"
            case .system: "system"
            }
        }
        var admin: Bool { self == .system }
    }

    // MARK: Read (scan time)

    public static func launchctlPrintDisabled(_ d: Domain) -> Command { Command(.launchctl, ["print-disabled", d.target]) }
    public static func launchctlList() -> Command { Command(.launchctl, ["list"]) }
    public static func launchctlPrint(_ d: Domain, label l: String) throws -> Command {
        Command(.launchctl, ["print", "\(d.target)/\(try label(l))"])
    }
    public static func pkgutilPackages() -> Command { Command(.pkgutil, ["--pkgs"]) }
    public static func pkgutilFiles(_ id: String) throws -> Command { Command(.pkgutil, ["--files", try label(id)]) }
    public static func systemExtensions() -> Command { Command(.systemextensionsctl, ["list"]) }
    public static func profilesList() -> Command { Command(.profiles, ["list"]) }
    public static func localSnapshots() -> Command { Command(.tmutil, ["listlocalsnapshots", "/"]) }
    public static func userCrontab() -> Command { Command(.crontab, ["-l"]) }
    public static func backgroundItems() -> Command { Command(.sfltool, ["dumpbtm"], admin: true) }

    // MARK: Act (plan steps)

    public static func bootout(_ d: Domain, label l: String) throws -> Command {
        Command(.launchctl, ["bootout", "\(d.target)/\(try label(l))"], admin: d.admin)
    }
    public static func disable(_ d: Domain, label l: String) throws -> Command {
        Command(.launchctl, ["disable", "\(d.target)/\(try label(l))"], admin: d.admin)
    }
    public static func enable(_ d: Domain, label l: String) throws -> Command {
        Command(.launchctl, ["enable", "\(d.target)/\(try label(l))"], admin: d.admin)
    }
    public static func deleteSnapshot(_ date: String) throws -> Command {
        guard date.wholeMatch(of: /\d{4}-\d{2}-\d{2}-\d{6}/) != nil else { throw SafetyError.badArgument(date) }
        return Command(.tmutil, ["deletelocalsnapshots", date], admin: true)
    }
    public static func deleteUnavailableSimulators() -> Command { Command(.xcrun, ["simctl", "delete", "unavailable"]) }
    public static func rebuildLaunchServices() -> Command {
        Command(.lsregister, ["-kill", "-r", "-domain", "local", "-domain", "system", "-domain", "user"])
    }
    public static func resetQuickLook() -> Command { Command(.qlmanage, ["-r", "cache"]) }
    public static func flushDNS() -> Command { Command(.dscacheutil, ["-flushcache"], admin: true) }
    public static func restartResolver() -> Command { Command(.killall, ["-HUP", "mDNSResponder"], admin: true) }
    public static func reindexSpotlight() -> Command { Command(.mdutil, ["-E", "/"], admin: true) }

    /// Moves a root-owned item into the user's Trash. `-n` never overwrites.
    /// The caller has already checked `source` against the system zones. The name ends in a random tag,
    /// so nothing can be planted at the destination ahead of time for root's `mv` to move into.
    public static func moveToTrash(_ source: URL, home: URL, now: Date = .now, tag: String = randomTag()) throws -> Command {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyyMMdd-HHmmss"
        let stamp = f.string(from: now)
        guard tag.wholeMatch(of: /[0-9a-f]{12}/) != nil else { throw SafetyError.badArgument(tag) }
        let dest = home.appending(path: ".Trash").appending(path: "\(source.lastPathComponent) \(stamp)-\(tag)")
        return Command(.mv, ["-n", try path(source), try path(dest)], admin: true)
    }

    public static func randomTag() -> String {
        String(UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased().prefix(12))
    }

    // MARK: Display

    static func quoted(_ s: String) -> String {
        s.wholeMatch(of: /[A-Za-z0-9._\/=:-]+/) != nil ? s : "'" + s.replacingOccurrences(of: "'", with: #"'\''"#) + "'"
    }

    /// The command as a shell line. Every argument is single-quoted if it needs it.
    public var shellLine: String { ([tool.rawValue] + args).map(Command.quoted).joined(separator: " ") }
    /// What the user sees under "Show commands".
    public var display: String { admin ? "sudo " + shellLine : shellLine }
}

public enum ExecError: Error, Equatable, CustomStringConvertible {
    case failed(status: Int32, message: String)
    case cancelled

    public var description: String {
        switch self {
        case .failed(let status, let message): "Exit \(status). \(message)"
        case .cancelled: "Cancelled at the admin prompt."
        }
    }
}

/// Runs commands. Tests swap in a fake.
public struct Runner: Sendable {
    public let run: @Sendable (Command) throws -> String

    public init(_ run: @escaping @Sendable (Command) throws -> String) { self.run = run }

    public static let live = Runner(Exec.run)
    /// Refuses everything. For views and previews that must never run anything.
    public static let none = Runner { throw SafetyError.badArgument($0.display) }
}

/// The only place MacPat starts another process.
public enum Exec {
    /// AppleScript string literal escaping for the admin path.
    static func appleScriptLiteral(_ s: String) -> String {
        "\"" + s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }

    /// The admin path. osascript shows the system prompt and runs the line as root.
    /// Every argument passed the factory checks and is single-quoted in `shellLine`.
    static func adminScript(_ c: Command) -> String {
        "do shell script \(appleScriptLiteral(c.shellLine)) with administrator privileges"
    }

    public static func run(_ c: Command) throws -> String {
        let p = Process()
        if c.admin {
            p.executableURL = URL(filePath: "/usr/bin/osascript")
            p.arguments = ["-e", adminScript(c)]
        } else {
            p.executableURL = URL(filePath: c.tool.rawValue)
            p.arguments = c.args
        }
        p.environment = ["PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "HOME": NSHomeDirectory(), "LANG": "en_US.UTF-8"]
        let out = Pipe()
        let err = Pipe()
        p.standardOutput = out
        p.standardError = err
        p.standardInput = FileHandle.nullDevice
        try p.run()
        // shortcut: reads stdout then stderr; a tool that fills the stderr pipe first would block. None here do.
        let data = out.fileHandleForReading.readDataToEndOfFile()
        let errData = err.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        let message = String(decoding: errData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        guard p.terminationStatus == 0 else {
            if c.admin, message.contains("-128") { throw ExecError.cancelled }
            throw ExecError.failed(status: p.terminationStatus, message: String(message.prefix(300)))
        }
        return String(decoding: data, as: UTF8.self)
    }
}
