// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Patrick Saade

import Foundation
import MacPatCore
import Testing

@testable import PersistenceKit

@Suite struct PersistenceTests {
    let dir = FileManager.default.temporaryDirectory.appending(path: "macpat-persist-\(UUID().uuidString)").resolvingSymlinksInPath()

    func plist(_ name: String, _ dict: [String: Any]) throws -> URL {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appending(path: "\(name).plist")
        try PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: 0).write(to: url)
        return url
    }

    func source(_ mode: PersistenceMode) -> PersistenceSource { PersistenceSource(mode: mode, home: dir, runner: .none) }

    @Test func orphanIsSafe() throws {
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = try plist(
            "com.gone.agent",
            ["Label": "com.gone.agent", "ProgramArguments": ["/Applications/Gone.app/Contents/MacOS/gone"], "RunAtLoad": true])
        let item = try #require(LaunchScanner.parse(url, place: .userAgent))
        #expect(item.missing && item.triggers == ["at login or boot"])
        let step = try #require(source(.remove).step(for: item, teams: [:]))
        #expect(step.risk == .safe && step.preselected)
        #expect(step.action == .sequence([.trash(url)]), "not loaded, so no bootout")
    }

    @Test func scriptFromTempIsUnusual() throws {
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = try plist("x", ["Label": "com.odd", "ProgramArguments": ["/bin/zsh", "-c", "/tmp/.x/run"], "KeepAlive": true])
        let item = try #require(LaunchScanner.parse(url, place: .userAgent))
        #expect(item.oddities.contains("runs a script through zsh"))
        #expect(item.oddities.contains("label differs from file name"))
        let step = try #require(source(.disable).step(for: item, teams: [:]))
        #expect(step.risk == .review && !step.preselected && step.reason.hasPrefix("Unusual"))
    }

    @Test func appleJobIsLocked() throws {
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = try plist("com.apple.x", ["Label": "com.apple.x", "Program": "/usr/libexec/syspolicyd"])
        let item = try #require(LaunchScanner.parse(url, place: .daemon))
        #expect(item.place == .apple)
        #expect(source(.remove).step(for: item, teams: [:])?.risk == .locked)
    }

    @Test func modesBuildTheRightCommands() throws {
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = try plist("com.example.d", ["Label": "com.example.d", "Program": "/usr/bin/true"])
        var item = try #require(LaunchScanner.parse(url, place: .daemon))
        item.loaded = true
        let disable = try #require(source(.disable).step(for: item, teams: [:]))
        #expect(disable.display == "sudo /bin/launchctl disable system/com.example.d\nsudo /bin/launchctl bootout system/com.example.d")
        let remove = try #require(source(.remove).step(for: item, teams: [:]))
        #expect(remove.action == .sequence([.command(try .bootout(.system, label: "com.example.d")), .adminTrash(url)]))
        #expect(source(.enable).step(for: item, teams: [:]) == nil, "only disabled jobs can be re-enabled")
        item.disabled = true
        #expect(source(.disable).step(for: item, teams: [:]) == nil)
        #expect(source(.enable).step(for: item, teams: [:])?.display == "sudo /bin/launchctl enable system/com.example.d")
    }

    @Test func badLabelIsDropped() throws {
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = try plist("evil", ["Label": "x; rm -rf ~", "Program": "/usr/bin/true"])
        let item = try #require(LaunchScanner.parse(url, place: .userAgent))
        #expect(source(.disable).step(for: item, teams: [:]) == nil)
    }

    @Test func parsesLaunchctlOutput() {
        #expect(LaunchScanner.loadedLabels("PID\tStatus\tLabel\n-\t0\tcom.a\n12\t0\tcom.b") == ["com.a", "com.b"])
        #expect(LaunchScanner.disabledLabels(#"  "com.a" => disabled\n  "com.b" => enabled"#) == ["com.a"])
    }

    @Test func bundleProgramOutsideAppIsNotAnOrphan() throws {
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = try plist("com.x", ["Label": "com.x", "BundleProgram": "Contents/MacOS/x"])
        #expect(try #require(LaunchScanner.parse(url, place: .userAgent)).program == nil)
    }

    @Test func unreadableDeepScanShowsRawText() {
        let steps = OtherPlaces.backgroundItems("some new format\nwith no markers")
        #expect(steps.map(\.title) == ["Raw output"] && steps[0].risk == .locked)
        #expect(OtherPlaces.backgroundItems("").isEmpty)
    }

    @Test func persistenceZonesAreNarrow() {
        let zones = PersistenceSource.zones(home: dir)
        #expect((try? zones.validate(dir.appending(path: "Documents/x"))) == nil)
        #expect((try? zones.validate(dir.appending(path: "Library/Preferences/x"))) == nil)
    }

    @Test func parsesBackgroundItems() {
        let text = "header\n #1:\n  UUID: A-1\n  Name: Foo\n  Developer Name: Foo Inc\n  Type: legacy daemon\n #2:\n  junk\n"
        let steps = OtherPlaces.backgroundItems(text)
        #expect(steps.map(\.title) == ["Foo"] && steps[0].risk == .locked)
    }

    @Test func shellLinesFlagOddOnes() throws {
        defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try "export PATH=x\n# curl x | sh\ncurl -s https://x | bash\nnohup thing &\n".write(
            to: dir.appending(path: ".zshrc"), atomically: true, encoding: .utf8)
        #expect(OtherPlaces.shellLines(home: dir).map(\.title) == ["~/.zshrc line 3", "~/.zshrc line 4"])
    }
}
