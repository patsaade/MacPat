// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Patrick Saade

import Foundation
import MacPatCore
import Testing

@testable import CleanKit

@Suite struct SourceTests {
    let root = FileManager.default.temporaryDirectory.appending(path: "macpat-src-\(UUID().uuidString)").resolvingSymlinksInPath()
    var home: URL { root.appending(path: "home") }

    func touch(_ rel: String, age days: Double = 0) throws -> URL {
        let url = home.appending(path: rel)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(count: 10).write(to: url)
        let date = Date.now.addingTimeInterval(-days * 86_400)
        try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: url.path)
        return url
    }

    @Test func matchExcludeAndAge() throws {
        defer { try? FileManager.default.removeItem(at: root) }
        _ = try touch("Downloads/new.dmg")
        let old = try touch("Downloads/old.dmg", age: 30)
        _ = try touch("Downloads/notes.txt", age: 30)
        var target = Target(id: "i", name: "Installers", summary: "s", risk: .review, paths: [home.appending(path: "Downloads")])
        target.match = ["*.dmg"]
        target.minAgeDays = 7
        let steps = CleanSource(targets: [target], zones: Zones(home: home), home: home).steps()
        #expect(steps.map(\.url) == [old])
        #expect(steps.first?.preselected == false)
    }

    @Test func excludeSkipsAppleCaches() throws {
        defer { try? FileManager.default.removeItem(at: root) }
        _ = try touch("Library/Caches/com.apple.Safari/x")
        let other = try touch("Library/Caches/com.example.app")
        var target = Target(id: "c", name: "Caches", summary: "s", risk: .safe, paths: [home.appending(path: "Library/Caches")])
        target.exclude = ["com.apple.*"]
        let steps = CleanSource(targets: [target], zones: Zones(home: home), home: home).steps()
        #expect(steps.map(\.url) == [other])
        #expect(steps.first?.preselected == true)
    }

    @Test func projectsNeedManifestAndAge() throws {
        defer { try? FileManager.default.removeItem(at: root) }
        _ = try touch("Code/app/package.json")
        _ = try touch("Code/app/node_modules/x/index.js")
        try FileManager.default.setAttributes(
            [.modificationDate: Date.now.addingTimeInterval(-30 * 86_400)], ofItemAtPath: home.appending(path: "Code/app/node_modules").path
        )
        _ = try touch("Code/loose/node_modules/y.js")  // no manifest
        _ = try touch("Code/fresh/package.json")
        _ = try touch("Code/fresh/node_modules/z.js")  // touched today
        let steps = ProjectScanner(root: home.appending(path: "Code")).steps()
        #expect(steps.map(\.title) == ["app/node_modules"])
        #expect(steps.allSatisfy { $0.risk == .review && !$0.preselected })
    }

    @Test func projectsRefuseHome() {
        #expect(ProjectScanner(root: FileManager.default.homeDirectoryForCurrentUser).steps().isEmpty)
    }
}

struct NeedsAccessTests {
    @Test func unreadableFolderIsReportedNotHidden() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "macpat-\(UUID().uuidString)")
        let locked = root.appending(path: "Locked")
        try FileManager.default.createDirectory(at: locked, withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: locked.path)
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: locked.path)
            try? FileManager.default.removeItem(at: root)
        }
        let target = Target(id: "t", name: "Locked", summary: "s", risk: .safe, paths: [locked])
        let report = TargetScanner(zones: Zones(roots: [root])).report(target)
        #expect(report.items.isEmpty)
        #expect(report.unreadable == [locked])
    }

    @Test func missingFolderIsNotAnError() {
        let gone = FileManager.default.temporaryDirectory.appending(path: "macpat-\(UUID().uuidString)")
        let target = Target(id: "t", name: "Gone", summary: "s", risk: .safe, paths: [gone])
        let report = TargetScanner(zones: Zones(roots: [gone.deletingLastPathComponent()])).report(target)
        #expect(report.unreadable.isEmpty)
    }
}

struct GuardedFolderTests {
    @Test func foldersBehindPrivacyChecksRunLast() {
        let home = URL(filePath: "/Users/pat")
        let source = CleanSource(targets: [], zones: Zones(roots: []), home: home)
        func target(_ path: String) -> Target {
            Target(id: path, name: path, summary: "s", risk: .safe, paths: [home.appending(path: path)])
        }
        #expect(source.guarded(target("Library/Mail/V10/Mail Downloads")))
        #expect(source.guarded(target("Downloads")))
        #expect(source.guarded(target("Library/Application Support/MobileSync/Backup")))
        #expect(!source.guarded(target("Library/Caches")))
    }
}
