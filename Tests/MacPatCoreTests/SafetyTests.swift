// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Patrick Saade

import Foundation
import Testing

@testable import MacPatCore

/// A throwaway home folder with the standard zones created inside it.
struct Sandbox {
    let root: URL
    let home: URL
    let outside: URL
    let caches: URL
    let zones: Zones

    init() throws {
        let fm = FileManager.default
        root = try fm.url(
            for: .itemReplacementDirectory, in: .userDomainMask,
            appropriateFor: fm.temporaryDirectory, create: true
        ).resolvingSymlinksInPath()
        home = root.appending(path: "home")
        outside = root.appending(path: "outside")
        caches = home.appending(path: "Library/Caches")
        try fm.createDirectory(at: caches, withIntermediateDirectories: true)
        try fm.createDirectory(at: home.appending(path: "Library/Logs"), withIntermediateDirectories: true)
        try fm.createDirectory(at: outside, withIntermediateDirectories: true)
        zones = Zones(home: home)
    }

    func file(_ name: String, in dir: URL? = nil, bytes: Int = 10) throws -> URL {
        let url = (dir ?? caches).appending(path: name)
        try Data(count: bytes).write(to: url)
        return url
    }

    func cleanup() { try? FileManager.default.removeItem(at: root) }
}

@Suite struct ZoneTests {
    @Test func acceptsChildOfZone() throws {
        let s = try Sandbox(); defer { s.cleanup() }
        let item = try s.file("a")
        #expect(try s.zones.validate(item) == item)
    }

    @Test func refusesZoneRootAndParents() throws {
        let s = try Sandbox(); defer { s.cleanup() }
        for url in [s.caches, s.caches.deletingLastPathComponent(), s.home, s.root, URL(filePath: "/")] {
            #expect(throws: SafetyError.self) { try s.zones.validate(url) }
        }
    }

    @Test func refusesSharedPrefixSibling() throws {
        let s = try Sandbox(); defer { s.cleanup() }
        let sibling = s.home.appending(path: "Library/Caches2/x")
        #expect(throws: SafetyError.outsideZones) { try s.zones.validate(sibling) }
    }

    @Test func refusesDotDot() throws {
        let s = try Sandbox(); defer { s.cleanup() }
        let sneaky = s.caches.appending(path: "a/../../../outside/x")
        #expect(throws: SafetyError.invalidPath) { try s.zones.validate(sneaky) }
    }

    @Test func symlinkItemIsHandledAsLink() throws {
        let s = try Sandbox(); defer { s.cleanup() }
        let target = try s.file("secret", in: s.outside)
        let link = s.caches.appending(path: "link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        #expect(try s.zones.validate(link) == link)
    }

    @Test func refusesItemBehindSymlinkedParent() throws {
        let s = try Sandbox(); defer { s.cleanup() }
        try FileManager.default.createSymbolicLink(at: s.caches.appending(path: "evil"), withDestinationURL: s.outside)
        _ = try s.file("secret", in: s.outside)
        let url = s.caches.appending(path: "evil/secret")
        #expect(throws: SafetyError.outsideZones) { try s.zones.validate(url) }
    }

    @Test func dropsZoneRootSymlinkedOutsideHome() throws {
        let s = try Sandbox(); defer { s.cleanup() }
        let fm = FileManager.default
        try fm.removeItem(at: s.home.appending(path: "Library/Logs"))
        try fm.createSymbolicLink(at: s.home.appending(path: "Library/Logs"), withDestinationURL: s.outside)
        let zones = Zones(home: s.home)
        #expect(zones.roots.allSatisfy { $0.pathComponents.starts(with: s.home.pathComponents) })
        #expect(zones.roots.count == Zones.standardPaths.count - 1)
        #expect(throws: SafetyError.outsideZones) { try zones.validate(s.outside.appending(path: "x")) }
    }

    /// Throws path pieces at the validator. Anything it accepts must sit under a zone root.
    @Test func neverAcceptsAnythingOutsideZones() throws {
        let s = try Sandbox(); defer { s.cleanup() }
        let pieces = ["..", ".", "a", "Caches", "Library", "", "%2e%2e", "é", "CACHES", "home", "outside"]
        var bases = [s.home, s.root, s.caches, s.outside, URL(filePath: "/")]
        var accepted = 0
        for _ in 0..<3 {
            bases = bases.flatMap { base in pieces.map { base.appending(path: $0) } }
            for url in bases {
                guard let ok = try? s.zones.validate(url) else { continue }
                accepted += 1
                let parts = ok.pathComponents
                #expect(s.zones.roots.contains { parts.count > $0.pathComponents.count && parts.starts(with: $0.pathComponents) })
            }
            bases = Array(bases.prefix(400))
        }
        #expect(accepted > 0)
    }
}

@Suite struct CleanerTests {
    @Test func dryRunDisposesNothing() throws {
        let s = try Sandbox(); defer { s.cleanup() }
        let item = Item(url: try s.file("a", bytes: 100), bytes: 100, targetID: "t")
        let out = Cleaner(zones: s.zones).run([item], dryRun: true) { _ in Issue.record("disposed") }
        #expect(out.count == 1 && out.bytes == 100 && out.failures.isEmpty && out.dryRun)
        #expect(FileManager.default.fileExists(atPath: item.url.path))
    }

    @Test func realRunDisposesEachItemOnce() throws {
        let s = try Sandbox(); defer { s.cleanup() }
        let item = Item(url: try s.file("a"), bytes: 10, targetID: "t")
        let log = Log()
        let out = Cleaner(zones: s.zones).run([item, item], dryRun: false) { log.add($0) }
        #expect(out.count == 1)
        #expect(log.urls == [item.url])
    }

    @Test func refusesItemsOutsideZones() throws {
        let s = try Sandbox(); defer { s.cleanup() }
        let stray = Item(url: try s.file("secret", in: s.outside), bytes: 10, targetID: "t")
        let out = Cleaner(zones: s.zones).run([stray], dryRun: false) { _ in Issue.record("disposed") }
        #expect(out.count == 0 && out.failures.count == 1)
    }

    @Test func linkIsDisposedNotItsTarget() throws {
        let s = try Sandbox(); defer { s.cleanup() }
        let target = try s.file("secret", in: s.outside)
        let link = s.caches.appending(path: "link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        let log = Log()
        _ = Cleaner(zones: s.zones).run([Item(url: link, bytes: 0, targetID: "t")], dryRun: false) { log.add($0) }
        #expect(log.urls == [link])
    }

    @Test func failureDoesNotStopTheRun() throws {
        let s = try Sandbox(); defer { s.cleanup() }
        let a = Item(url: try s.file("a"), bytes: 1, targetID: "t")
        let b = Item(url: try s.file("b"), bytes: 2, targetID: "t")
        struct Boom: Error {}
        let out = Cleaner(zones: s.zones).run([a, b], dryRun: false) { if $0 == a.url { throw Boom() } }
        #expect(out.count == 1 && out.bytes == 2 && out.failures.count == 1)
    }
}

@Suite struct ScannerTests {
    @Test func listsChildrenWithSizes() throws {
        let s = try Sandbox(); defer { s.cleanup() }
        let dir = s.caches.appending(path: "app")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        _ = try s.file("blob", in: dir, bytes: 50_000)
        _ = try s.file("loose", bytes: 10)
        let target = Target(id: "t", name: "T", summary: "", risk: .safe, paths: [s.caches])
        let items = TargetScanner(zones: s.zones).scan(target)
        #expect(items.count == 2)
        #expect(items.first { $0.url == dir }!.bytes >= 50_000)
    }

    @Test func ignoresTargetPathsOutsideZones() throws {
        let s = try Sandbox(); defer { s.cleanup() }
        _ = try s.file("secret", in: s.outside)
        let target = Target(id: "t", name: "T", summary: "", risk: .safe, paths: [s.outside, s.home])
        #expect(TargetScanner(zones: s.zones).scan(target).isEmpty)
    }

    @Test func doesNotCountThroughSymlinkedFolders() throws {
        let s = try Sandbox(); defer { s.cleanup() }
        _ = try s.file("big", in: s.outside, bytes: 1_000_000)
        try FileManager.default.createSymbolicLink(at: s.caches.appending(path: "link"), withDestinationURL: s.outside)
        let target = Target(id: "t", name: "T", summary: "", risk: .safe, paths: [s.caches])
        #expect(TargetScanner(zones: s.zones).scan(target).allSatisfy { $0.bytes < 100_000 })
    }
}

final class Log: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [URL] = []
    var urls: [URL] { lock.withLock { stored } }
    func add(_ url: URL) { lock.withLock { stored.append(url) } }
}
