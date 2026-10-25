// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Patrick Saade

import Foundation
import MacPatCore

/// Startup places outside launchd. Most are shown, not changed: MacPat can't remove them safely,
/// so each says how to do it by hand.
enum OtherPlaces {
    static let inspect = "Startup places MacPat only shows"

    static func locked(_ title: String, _ reason: String, _ facts: [Fact], key: String) -> Step {
        Step(
            group: inspect, title: title, risk: .locked, reason: reason, facts: facts, action: .none,
            preselected: false, id: key)
    }

    static func cron(_ runner: Runner) -> [Step] {
        let text = (try? runner.run(.userCrontab())) ?? ""
        return text.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") && $0.wholeMatch(of: /[A-Za-z_]+=.*/) == nil }
            .map { locked("Cron job", "Runs on a schedule. Edit with: crontab -e", [Fact("Line", $0)], key: "cron:\($0)") }
    }

    static func loginHooks(home: URL) -> [Step] {
        [
            URL(filePath: "/Library/Preferences/com.apple.loginwindow.plist"),
            home.appending(path: "Library/Preferences/com.apple.loginwindow.plist"),
        ]
        .flatMap { url -> [Step] in
            guard let data = try? Data(contentsOf: url),
                let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
            else { return [] }
            return ["LoginHook", "LogoutHook"].compactMap { key in
                (dict[key] as? String).map {
                    locked(
                        key, "An old way to run a script as root at login. Remove with: sudo defaults delete com.apple.loginwindow \(key)",
                        [Fact("Script", $0), Fact("Set in", url.path)], key: "hook:\(url.path):\(key)")
                }
            }
        }
    }

    static func profiles(_ runner: Runner) -> [Step] {
        let text = (try? runner.run(.profilesList())) ?? ""
        return text.matches(of: /profileIdentifier: (\S+)/).map {
            let id = String($0.output.1)
            return locked(
                id,
                "A configuration profile can change settings and install certificates. Remove it in System Settings, General, Device Management.",
                [], key: "profile:\(id)")
        }
    }

    static func systemExtensions(_ runner: Runner) -> [Step] {
        let text = (try? runner.run(.systemExtensions())) ?? ""
        return text.split(separator: "\n").compactMap { line -> Step? in
            let cols = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard cols.count >= 6, cols[2].wholeMatch(of: /[A-Z0-9]{10}/) != nil else { return nil }
            return locked(
                cols[4], "A system extension. Remove it by deleting its app, or in System Settings, General, Login Items & Extensions.",
                [Fact("Team ID", cols[2]), Fact("Bundle", cols[3]), Fact("State", cols[5])], key: "sysext:\(cols[3])")
        }
    }

    static func bundles(_ dir: String, ext: String, reason: String) -> [Step] {
        let url = URL(filePath: dir)
        let items = ((try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)) ?? []).filter {
            $0.pathExtension == ext
        }
        return items.map {
            locked(
                $0.lastPathComponent, reason, [Fact("Path", $0.path), Fact("Signed by", Signing.check($0).summary)],
                key: "bundle:\($0.path)")
        }
    }

    static func kernelAndAuth() -> [Step] {
        bundles("/Library/Extensions", ext: "kext", reason: "A kernel extension. Remove it with its vendor's uninstaller.")
            + bundles(
                "/Library/Security/SecurityAgentPlugins", ext: "bundle",
                reason: "Runs inside the login window. A broken one can lock you out, so MacPat leaves it alone.")
            + bundles(
                "/Library/DirectoryServices/PlugIns", ext: "dsplug",
                reason: "Plugs into account lookup. Remove with its vendor's uninstaller.")
    }

    /// Lines in shell startup files that fetch, launch, or background things.
    static func shellLines(home: URL) -> [Step] {
        let files = [".zshrc", ".zprofile", ".zshenv", ".zlogin", ".bash_profile", ".bashrc", ".profile", ".config/fish/config.fish"]
        let odd = /(curl|wget)\s.*\|\s*\w*sh|nohup|osascript|launchctl|base64\s+(-d|--decode)|python3?\s+-c|disown|&\s*$/
        return files.flatMap { name -> [Step] in
            let url = home.appending(path: name)
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
            return text.split(separator: "\n", omittingEmptySubsequences: false).enumerated().compactMap { n, raw in
                let line = raw.trimmingCharacters(in: .whitespaces)
                guard !line.hasPrefix("#"), line.firstMatch(of: odd) != nil else { return nil }
                return locked(
                    "~/\(name) line \(n + 1)", "Runs every time a shell starts. MacPat never edits shell files. Open it and decide.",
                    [Fact("Line", String(line.prefix(160))), Fact("File", url.path)], key: "rc:\(url.path):\(n)")
            }
        }
    }

    /// Entries from `sfltool dumpbtm`, the list behind Login Items & Extensions.
    /// The format changes between macOS versions, so parsing is loose and keeps raw fields.
    static func backgroundItems(_ text: String) -> [Step] {
        let parsed = parseBackgroundItems(text)
        guard parsed.isEmpty, !text.isEmpty else { return parsed }
        return [
            Step(
                group: "Background items (deep scan)", title: "Raw output", risk: .locked,
                reason: "MacPat couldn't read this macOS version's format, so here is the start of it as is.",
                facts: [Fact("sfltool", String(text.prefix(2000)))], action: .none, preselected: false, id: "btm:raw")
        ]
    }

    static func parseBackgroundItems(_ text: String) -> [Step] {
        text.components(separatedBy: "\n #").dropFirst().compactMap { block -> Step? in
            var fields: [String: String] = [:]
            for line in block.split(separator: "\n") {
                guard let colon = line.firstIndex(of: ":") else { continue }
                let key = line[..<colon].trimmingCharacters(in: .whitespaces)
                let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
                if fields[key] == nil, !value.isEmpty { fields[key] = value }
            }
            guard let name = fields["Name"] ?? fields["Identifier"], let id = fields["UUID"] ?? fields["Identifier"] else { return nil }
            let facts = ["Developer Name", "Type", "Disposition", "Identifier", "URL", "Executable Path"].compactMap { key in
                fields[key].map { Fact(key, $0) }
            }
            return Step(
                group: "Background items (deep scan)", title: name, risk: .locked,
                reason: "Listed in System Settings, General, Login Items & Extensions. Turn it off there.", facts: facts,
                action: .none, preselected: false, id: "btm:\(id)")
        }
    }
}
