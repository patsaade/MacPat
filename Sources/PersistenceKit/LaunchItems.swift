// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Patrick Saade

import Foundation
import MacPatCore

/// A launchd job: a plist that starts a program at login, at boot, or on a schedule.
public struct LaunchItem: Sendable, Hashable {
    public enum Place: String, Sendable, CaseIterable {
        case userAgent = "Your login agents"
        case globalAgent = "Login agents for every user"
        case daemon = "System daemons"
        case inApp = "Inside apps (managed by macOS)"
        case apple = "Part of macOS"
    }

    public let plist: URL
    public let label: String
    public let program: URL?
    public let arguments: [String]
    public let triggers: [String]
    public let place: Place
    public let signature: Signature
    public var loaded = false
    public var disabled = false
    public init(
        plist: URL, label: String, program: URL?, arguments: [String], triggers: [String], place: Place, signature: Signature
    ) {
        self.plist = plist
        self.label = label
        self.program = program
        self.arguments = arguments
        self.triggers = triggers
        self.place = place
        self.signature = signature
    }

    public var modified: Date? { try? plist.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate }

    /// The app bundle the program lives in, if any.
    public var app: URL? {
        guard let program else { return nil }
        let parts = program.pathComponents
        guard let i = parts.firstIndex(where: { $0.hasSuffix(".app") }) else { return nil }
        return URL(filePath: parts[...i].joined(separator: "/").replacingOccurrences(of: "//", with: "/"))
    }

    public var domain: Command.Domain { place == .daemon ? .system : .gui(getuid()) }
    public var missing: Bool { signature.kind == .missing }

    /// What looks out of place. Not proof of harm.
    public var oddities: [String] {
        var out: [String] = []
        if signature.kind == .unsigned { out.append("unsigned program") }
        if signature.kind == .adHoc { out.append("ad-hoc signed program") }
        if let path = program?.path {
            if path.contains("/.") { out.append("runs from a hidden folder") }
            if ["/tmp/", "/private/tmp/", "/private/var/folders/", "/Users/Shared/"].contains(where: path.hasPrefix) {
                out.append("runs from a temporary or shared folder")
            }
            let name = program!.lastPathComponent
            if ["sh", "bash", "zsh", "python", "python3", "perl", "ruby", "osascript", "node"].contains(name), arguments.count > 1 {
                out.append("runs a script through \(name)")
            }
        }
        if label != plist.deletingPathExtension().lastPathComponent, place != .inApp { out.append("label differs from file name") }
        return out
    }
}

public enum LaunchScanner {
    /// Reads every launchd plist in the standard places. `runner` reads loaded and disabled state.
    public static func scan(home: URL, includeApple: Bool, apps: [AppInfo], runner: Runner) -> [LaunchItem] {
        var dirs: [(URL, LaunchItem.Place)] = [
            (home.appending(path: "Library/LaunchAgents"), .userAgent),
            (URL(filePath: "/Library/LaunchAgents"), .globalAgent),
            (URL(filePath: "/Library/LaunchDaemons"), .daemon),
        ]
        for app in apps {
            dirs.append((app.url.appending(path: "Contents/Library/LaunchAgents"), .inApp))
            dirs.append((app.url.appending(path: "Contents/Library/LaunchDaemons"), .inApp))
        }
        if includeApple {
            dirs.append((URL(filePath: "/System/Library/LaunchAgents"), .apple))
            dirs.append((URL(filePath: "/System/Library/LaunchDaemons"), .apple))
        }
        let fm = FileManager.default
        var items: [LaunchItem] = []
        for (dir, place) in dirs {
            let files = ((try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []).filter {
                $0.pathExtension == "plist"
            }
            // Checking a code signature is slow and independent per file, so do them side by side.
            items += concurrentMap(files.sorted { $0.path < $1.path }) { parse($0, place: place) }.compactMap { $0 }
        }
        let uid = getuid()
        let guiLoaded = loadedLabels((try? runner.run(.launchctlList())) ?? "")
        let disabled =
            disabledLabels((try? runner.run(.launchctlPrintDisabled(.gui(uid)))) ?? "")
            .union(disabledLabels((try? runner.run(.launchctlPrintDisabled(.system))) ?? ""))
        return concurrentMap(items) { item in
            var item = item
            item.disabled = disabled.contains(item.label)
            if item.place == .daemon {
                item.loaded = (try? Command.launchctlPrint(.system, label: item.label)).map { (try? runner.run($0)) != nil } ?? false
            } else {
                item.loaded = guiLoaded.contains(item.label)
            }
            return item
        }
    }

    static func parse(_ plist: URL, place: LaunchItem.Place) -> LaunchItem? {
        guard let size = try? plist.resourceValues(forKeys: [.fileSizeKey]).fileSize, size < 1_000_000,
            let data = try? Data(contentsOf: plist),
            let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return nil }
        let label = (dict["Label"] as? String) ?? plist.deletingPathExtension().lastPathComponent
        let args = (dict["ProgramArguments"] as? [String]) ?? []
        var path = (dict["Program"] as? String) ?? args.first
        if path == nil, place == .inApp, let relative = dict["BundleProgram"] as? String {
            // SMAppService plists point inside their own app bundle.
            let bundle = plist.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
                .deletingLastPathComponent()
            path = bundle.appending(path: relative).path
        }
        let program = path.flatMap { $0.hasPrefix("/") ? URL(filePath: $0) : nil }
        var triggers: [String] = []
        if dict["RunAtLoad"] as? Bool == true { triggers.append("at login or boot") }
        if let keep = dict["KeepAlive"], (keep as? Bool) != false { triggers.append("kept running") }
        if let interval = dict["StartInterval"] as? Int { triggers.append("every \(interval) s") }
        if dict["StartCalendarInterval"] != nil { triggers.append("on a schedule") }
        if dict["WatchPaths"] != nil || dict["QueueDirectories"] != nil { triggers.append("when files change") }
        if dict["MachServices"] != nil || dict["Sockets"] != nil { triggers.append("on demand") }
        let signature = program.map(Signing.check) ?? Signature(kind: .missing, teamID: nil, identifier: nil)
        let apple = label.hasPrefix("com.apple.") && signature.kind == .apple
        return LaunchItem(
            plist: plist, label: label, program: program, arguments: args, triggers: triggers, place: apple ? .apple : place,
            signature: signature)
    }

    /// Labels from `launchctl list`: PID, status, label.
    static func loadedLabels(_ text: String) -> Set<String> {
        Set(text.split(separator: "\n").dropFirst().compactMap { $0.split(separator: "\t").last.map(String.init) })
    }

    /// `"label" => disabled` lines from `launchctl print-disabled`.
    static func disabledLabels(_ text: String) -> Set<String> {
        Set(text.matches(of: /"([^"]+)" => (?:disabled|true)/).map { String($0.output.1) })
    }
}
