// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Patrick Saade

import Foundation
import MacPatCore
import Testing

@testable import AnalyzeKit

@Suite struct AnalyzeTests {
    let home = FileManager.default.temporaryDirectory.appending(path: "macpat-an-\(UUID().uuidString)").resolvingSymlinksInPath()

    @Test func sizesChildrenLargestFirst() async throws {
        defer { try? FileManager.default.removeItem(at: home) }
        let big = home.appending(path: "big")
        try FileManager.default.createDirectory(at: big, withIntermediateDirectories: true)
        try Data(count: 200_000).write(to: big.appending(path: "a"))
        try Data(count: 10).write(to: home.appending(path: "small"))
        let entries = await FolderSizer.children(of: home)
        #expect(entries.map(\.url.lastPathComponent) == ["big", "small"])
        #expect(entries[0].isFolder && entries[0].bytes >= 200_000)
    }

    @Test func largeOldNeedsSizeAndAgeAndSkipsLibrary() throws {
        defer { try? FileManager.default.removeItem(at: home) }
        let fm = FileManager.default
        for rel in ["Movies/old.mov", "Movies/new.mov", "Library/old.bin"] {
            let url = home.appending(path: rel)
            try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(count: 3000).write(to: url)
        }
        let old = Date.now.addingTimeInterval(-400 * 86_400)
        for rel in ["Movies/old.mov", "Library/old.bin"] {
            try fm.setAttributes([.modificationDate: old], ofItemAtPath: home.appending(path: rel).path)
        }
        var scanner = LargeOldScanner(home: home)
        scanner.minBytes = 1000
        #expect(scanner.steps().map(\.title) == ["old.mov"])
    }

    @Test func zonesAreFixedAndSkipLibraryAndLinks() throws {
        defer { try? FileManager.default.removeItem(at: home) }
        let fm = FileManager.default
        try fm.createDirectory(at: home.appending(path: "Library/Keychains"), withIntermediateDirectories: true)
        try fm.createDirectory(at: home.appending(path: "Documents"), withIntermediateDirectories: true)
        try fm.createSymbolicLink(at: home.appending(path: "Movies"), withDestinationURL: home.appending(path: "Library"))
        let zones = LargeOldScanner.zones(home: home)
        #expect(zones.roots.contains { $0.lastPathComponent == "Documents" })
        #expect(!zones.roots.contains { $0.lastPathComponent == "Movies" || $0.lastPathComponent == "Library" })
        #expect((try? zones.validate(home.appending(path: "Movies/Keychains/x"))) == nil)
    }

    @Test func parsesSnapshots() {
        let text = "Snapshots for disk /:\ncom.apple.TimeMachine.2026-10-24-101500.local\ncom.apple.TimeMachine.2026-10-23-090000.local\n"
        #expect(VolumeSummary.parseSnapshots(text) == ["2026-10-24-101500", "2026-10-23-090000"])
    }
}
