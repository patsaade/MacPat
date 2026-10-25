// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Patrick Saade

import Foundation
import MacPatCore
import PersistenceKit
import Testing

@testable import UninstallKit

@Suite struct LeftoverTests {
    let home = FileManager.default.temporaryDirectory.appending(path: "macpat-un-\(UUID().uuidString)").resolvingSymlinksInPath()

    func make(_ rel: String) throws {
        let url = home.appending(path: rel)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(count: 10).write(to: url)
    }

    var app: AppInfo {
        AppInfo(
            url: home.appending(path: "Applications/Widget.app"), name: "Widget", bundleID: "com.example.widget",
            signature: Signature(kind: .developerID, teamID: "ABCDE12345"))
    }

    @Test func matchTiers() throws {
        defer { try? FileManager.default.removeItem(at: home) }
        try make("Applications/Widget.app/Contents/Info.plist")
        try make("Library/Preferences/com.example.widget.plist")
        try make("Library/Caches/com.example.widget.helper/x")
        try make("Library/Group Containers/ABCDE12345.shared/x")
        try make("Library/Application Support/Widget/x")
        try make("Library/Application Support/com.example.widgetry/x")  // different app, shares a prefix
        try make("Library/Application Support/Other/x")
        let steps = LeftoverScanner(app: app, home: home).steps()
        let byTitle = Dictionary(steps.filter { $0.group != "App" }.map { ($0.title, $0) }, uniquingKeysWith: { a, _ in a })
        #expect(byTitle["com.example.widget.plist"]?.risk == .safe && byTitle["com.example.widget.plist"]?.preselected == true)
        #expect(byTitle["com.example.widget.helper"]?.risk == .safe)
        #expect(byTitle["ABCDE12345.shared"]?.risk == .review)
        #expect(byTitle["Widget"]?.risk == .review && byTitle["Widget"]?.preselected == false)
        #expect(byTitle["com.example.widgetry"] == nil && byTitle["Other"] == nil)
        #expect(steps.first?.group == "App" && steps.first?.title == "Widget")
    }

    @Test func runningAppIsLockedAndAppleIsRefused() throws {
        defer { try? FileManager.default.removeItem(at: home) }
        var scanner = LeftoverScanner(app: app, home: home)
        scanner.running = ["com.example.widget"]
        #expect(scanner.steps().first?.risk == .locked)
        let apple = AppInfo(
            url: URL(filePath: "/Applications/Safari.app"), name: "Safari", bundleID: "com.apple.Safari", signature: Signature(kind: .apple)
        )
        #expect(LeftoverScanner(app: apple, home: home).steps().map(\.risk) == [.locked])
    }

    @Test func orphansSkipInstalledAndApple() throws {
        defer { try? FileManager.default.removeItem(at: home) }
        try make("Library/Preferences/com.gone.app.plist")
        try make("Library/Preferences/com.here.app.plist")
        try make("Library/Preferences/com.apple.finder.plist")
        try make("Library/Preferences/loose.plist")
        let steps = OrphanScanner(home: home) { $0 == "com.here.app" }.steps()
        #expect(steps.map(\.title) == ["com.gone.app.plist"])
        #expect(steps.allSatisfy { $0.risk == .review && !$0.preselected })
    }

    @Test func vagueOrAppleBundleIDsMatchNothing() throws {
        defer { try? FileManager.default.removeItem(at: home) }
        try make("Library/Preferences/com.apple.finder.plist")
        try make("Library/Preferences/com.other.thing.plist")
        for id in ["com.apple", "com", "com.other"] {
            let fake = AppInfo(
                url: home.appending(path: "Applications/Fake.app"), name: "Fake", bundleID: id, signature: Signature(kind: .unsigned))
            let found = LeftoverScanner(app: fake, home: home).steps().filter { $0.group != "App" }
            #expect(found.isEmpty, "\(id) matched \(found.map(\.title))")
        }
    }

    @Test func launchLabelsNeedADotBoundary() throws {
        var scanner = LeftoverScanner(app: app, home: home)
        func item(_ label: String) -> LaunchItem {
            LaunchItem(
                plist: home.appending(path: "Library/LaunchAgents/\(label).plist"), label: label, program: URL(filePath: "/usr/bin/true"),
                arguments: [], triggers: [], place: .userAgent, signature: Signature(kind: .apple))
        }
        scanner.launchItems = [item("com.example.widget.agent"), item("com.example.widgetry.agent"), item("com.example.widget")]
        #expect(Set(scanner.launchSteps().map(\.title)) == ["com.example.widget.agent", "com.example.widget"])
    }

    @Test func runningAppLocksEveryLeftover() throws {
        defer { try? FileManager.default.removeItem(at: home) }
        try make("Library/Preferences/com.example.widget.plist")
        var scanner = LeftoverScanner(app: app, home: home)
        scanner.running = ["com.example.widget"]
        let steps = scanner.steps()
        #expect(steps.count == 2 && steps.allSatisfy { $0.risk == .locked && !$0.preselected })
    }

    @Test func zonesCoverLibraryAndApplicationsOnly() throws {
        let zones = LeftoverScanner.zones(home: home)
        #expect((try? zones.validate(URL(filePath: "/Applications/Foo.app"))) != nil)
        #expect((try? zones.validate(URL(filePath: "/Applications/Safari.app"))) == nil)
        #expect((try? zones.validate(home.appending(path: "Documents/x"))) == nil)
        #expect((try? zones.validate(home.appending(path: "Library/Preferences/com.apple.finder.plist"))) == nil)
    }
}
