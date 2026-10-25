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

    @Test func dropsZoneRootThatIsASymlinkInsideHome() throws {
        let s = try Sandbox(); defer { s.cleanup() }
        try FileManager.default.createSymbolicLink(
            at: s.home.appending(path: "Movies"), withDestinationURL: s.home.appending(path: "Library"))
        let zones = Zones(home: s.home, relativePaths: ["Movies", "Library/Caches"])
        #expect(zones.roots.map(\.path) == [s.caches.path])
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

@Suite struct ExecutorTests {
    func plan(_ items: [URL], bytes: Int64 = 10) -> Plan {
        Plan(items.map { Step(group: "g", title: $0.lastPathComponent, bytes: bytes, risk: .safe, reason: "", action: .trash($0)) })
    }

    @Test func dryRunDisposesNothing() throws {
        let s = try Sandbox(); defer { s.cleanup() }
        let url = try s.file("a", bytes: 100)
        let out = Executor(zones: s.zones, dispose: { _ in Issue.record("disposed") }).run(
            plan([url], bytes: 100), previewed: nil, dryRun: true)
        #expect(out.count == 1 && out.bytes == 100 && out.failures.isEmpty && out.dryRun)
        #expect(FileManager.default.fileExists(atPath: url.path))
    }

    @Test func realRunDisposesEachItemOnce() throws {
        let s = try Sandbox(); defer { s.cleanup() }
        let url = try s.file("a")
        let log = Log()
        let p = plan([url, url])
        let out = Executor(zones: s.zones, dispose: { log.add($0) }).run(p, previewed: p.fingerprint, dryRun: false)
        #expect(out.count == 1)
        #expect(log.urls == [url])
    }

    @Test func refusesWithoutMatchingPreview() throws {
        let s = try Sandbox(); defer { s.cleanup() }
        let p = plan([try s.file("a")])
        let ex = Executor(zones: s.zones, dispose: { _ in Issue.record("disposed") })
        #expect(ex.run(p, previewed: nil, dryRun: false).refused != nil)
        #expect(ex.run(p, previewed: "stale", dryRun: false).refused != nil)
    }

    @Test func fingerprintChangesWhenFileIsSwapped() throws {
        let s = try Sandbox(); defer { s.cleanup() }
        let url = try s.file("a")
        let before = plan([url]).fingerprint
        try Data(count: 99).write(to: url)
        #expect(plan([url]).fingerprint == before, "new content keeps the same file")
        try FileManager.default.removeItem(at: url)
        try FileManager.default.createSymbolicLink(at: url, withDestinationURL: s.outside)
        #expect(plan([url]).fingerprint != before, "a swapped link must not match")
    }

    @Test func refusesItemsOutsideZones() throws {
        let s = try Sandbox(); defer { s.cleanup() }
        let p = plan([try s.file("secret", in: s.outside)])
        let out = Executor(zones: s.zones, dispose: { _ in Issue.record("disposed") }).run(p, previewed: p.fingerprint, dryRun: false)
        #expect(out.count == 0 && out.failures.count == 1)
    }

    @Test func lockedStepsNeverRun() throws {
        let s = try Sandbox(); defer { s.cleanup() }
        let url = try s.file("a")
        let p = Plan([Step(group: "g", title: "a", risk: .locked, reason: "", action: .trash(url))])
        let out = Executor(zones: s.zones, dispose: { _ in Issue.record("disposed") }).run(p, previewed: p.fingerprint, dryRun: false)
        #expect(out.count == 0 && out.failures.first?.reason == SafetyError.locked.description)
    }

    @Test func linkIsDisposedNotItsTarget() throws {
        let s = try Sandbox(); defer { s.cleanup() }
        let target = try s.file("secret", in: s.outside)
        let link = s.caches.appending(path: "link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        let log = Log()
        let p = plan([link])
        _ = Executor(zones: s.zones, dispose: { log.add($0) }).run(p, previewed: p.fingerprint, dryRun: false)
        #expect(log.urls == [link])
    }

    @Test func failureDoesNotStopTheRun() throws {
        let s = try Sandbox(); defer { s.cleanup() }
        let a = try s.file("a")
        let b = try s.file("b")
        struct Boom: Error {}
        let p = Plan([
            Step(group: "g", title: "a", bytes: 1, risk: .safe, reason: "", action: .trash(a)),
            Step(group: "g", title: "b", bytes: 2, risk: .safe, reason: "", action: .trash(b)),
        ])
        let out = Executor(zones: s.zones, dispose: { if $0 == a { throw Boom() } }).run(p, previewed: p.fingerprint, dryRun: false)
        #expect(out.count == 1 && out.bytes == 2 && out.failures.count == 1)
    }

    @Test func adminTrashGoesThroughSystemZonesAndMv() throws {
        let s = try Sandbox(); defer { s.cleanup() }
        let ran = Commands()
        let runner = Runner {
            ran.add($0); return ""
        }
        let ok = URL(filePath: "/Library/LaunchDaemons/com.example.helper.plist")
        let bad = URL(filePath: "/System/Library/LaunchDaemons/com.example.plist")
        let apple = URL(filePath: "/Library/LaunchDaemons/com.apple.thing.plist")
        let p = Plan([ok, bad, apple].map { Step(group: "g", title: "x", risk: .review, reason: "", action: .adminTrash($0)) })
        let out = Executor(zones: s.zones, home: s.home, runner: runner).run(p, previewed: p.fingerprint, dryRun: false)
        #expect(out.count == 1 && out.failures.count == 2)
        let mv = try #require(ran.all.first)
        #expect(mv.tool == .mv && mv.admin && mv.args[1] == ok.path && mv.args[2].hasPrefix(s.home.appending(path: ".Trash").path))
    }

    @Test func writesActionLog() throws {
        let s = try Sandbox(); defer { s.cleanup() }
        let log = ActionLog(url: s.root.appending(path: "log/actions.jsonl"))
        let p = plan([try s.file("a")])
        _ = Executor(zones: s.zones, dispose: { _ in }, log: log).run(p, previewed: p.fingerprint, dryRun: false)
        _ = Executor(zones: s.zones, dispose: { _ in }, log: log).run(p, previewed: p.fingerprint, dryRun: false)
        let text = try String(contentsOf: log.url, encoding: .utf8)
        #expect(text.split(separator: "\n").count == 2 && text.contains(p.fingerprint))
    }
}

@Suite struct SystemZoneTests {
    @Test(arguments: [
        "/Library/LaunchDaemons/com.example.x.plist", "/Library/Caches/com.example", "/Applications/Example.app",
        "/Library/Application Support/Example",
    ])
    func acceptsSystemItems(path: String) throws {
        #expect(try Zones.system.validate(URL(filePath: path)).path == path)
    }

    @Test(arguments: [
        "/System/Library/LaunchDaemons/x.plist", "/usr/bin/true", "/Library/Apple/x", "/Library/Application Support/Apple/x",
        "/Library/Preferences/SystemConfiguration/preferences.plist", "/Library/LaunchDaemons/com.apple.x.plist",
        "/Applications/Utilities/Terminal.app", "/Applications/Safari.app", "/Library/LaunchDaemons", "/Library", "/",
        "/private/etc/hosts", "/Users/x", "/Library/Caches/../../System",
    ])
    func refusesProtected(path: String) {
        #expect(throws: SafetyError.self) { try Zones.system.validate(URL(filePath: path)) }
    }

    @Test func dropsBroadRoots() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let zones = Zones(roots: ["/", "/Users", "/Library", "/System/Library", "/usr"].map { URL(filePath: $0) } + [home])
        #expect(zones.roots.isEmpty)
    }
}

@Suite struct CommandTests {
    static let nasty = [
        "a b", "a'b", "a\"b", "a;rm -rf ~", "$(id)", "`id`", "a\nb", "a\u{0}b", "", "-rf", "../x", "a/b", "é", "a|b", "a&b",
        "a>b", "*", "~",
    ]

    @Test(arguments: nasty)
    func labelsRejectShellAndOddCharacters(arg: String) {
        #expect(throws: SafetyError.self) { try Command.bootout(.gui(501), label: arg) }
        #expect(throws: SafetyError.self) { try Command.disable(.system, label: arg) }
        #expect(throws: SafetyError.self) { try Command.enable(.gui(501), label: arg) }
        #expect(throws: SafetyError.self) { try Command.launchctlPrint(.system, label: arg) }
        #expect(throws: SafetyError.self) {
            try Command.moveToTrash(URL(filePath: "/Library/Caches/x"), home: URL(filePath: "/Users/pat"), tag: arg)
        }
        #expect(throws: SafetyError.self) { try Command.pkgutilFiles(arg) }
        #expect(throws: SafetyError.self) { try Command.deleteSnapshot(arg) }
    }

    @Test func acceptsRealLabelsAndDates() throws {
        #expect(
            try Command.bootout(.system, label: "com.example.helper").display == "sudo /bin/launchctl bootout system/com.example.helper")
        #expect(try Command.disable(.gui(501), label: "io.x-y_z.Agent").shellLine == "/bin/launchctl disable gui/501/io.x-y_z.Agent")
        #expect(try Command.deleteSnapshot("2026-10-24-101500").args == ["deletelocalsnapshots", "2026-10-24-101500"])
    }

    @Test func mvQuotesPathsWithSpacesAndQuotes() throws {
        let src = URL(filePath: "/Library/Application Support/Bob's \"App\"")
        let c = try Command.moveToTrash(src, home: URL(filePath: "/Users/pat"), now: Date(timeIntervalSince1970: 0))
        #expect(c.args[1] == src.path)
        #expect(c.shellLine.contains(#"'/Library/Application Support/Bob'\''s "App"'"#))
        let script = Exec.adminScript(c)
        #expect(script.hasPrefix("do shell script \"") && script.hasSuffix("\" with administrator privileges"))
        #expect(script.contains(#"\"App\""#))
    }

    @Test func trashNameEndsInRandomTag() throws {
        let a = try Command.moveToTrash(URL(filePath: "/Library/Caches/x"), home: URL(filePath: "/Users/pat"))
        let b = try Command.moveToTrash(URL(filePath: "/Library/Caches/x"), home: URL(filePath: "/Users/pat"))
        #expect(a.args[2] != b.args[2])
        #expect(a.args[2].wholeMatch(of: /\/Users\/pat\/\.Trash\/x \d{8}-\d{6}-[0-9a-f]{12}/) != nil)
    }

    @Test func mvRejectsControlCharactersAndDots() {
        for p in ["/Library/Caches/a\nb", "/Library/Caches/../x"] {
            #expect(throws: SafetyError.self) { try Command.moveToTrash(URL(filePath: p), home: URL(filePath: "/Users/pat")) }
        }
    }

    @Test func everyToolExists() {
        for tool in Tool.allCases { #expect(FileManager.default.isExecutableFile(atPath: tool.rawValue), "\(tool)") }
    }
}

@Suite struct IgnoreTests {
    @Test func coversChildrenAndOwnLog() {
        var list = IgnoreList()
        list.add(URL(filePath: "/Users/pat/Library/Caches/keep"))
        let home = URL(filePath: "/Users/pat")
        #expect(list.contains(URL(filePath: "/Users/pat/Library/Caches/keep/x"), home: home))
        #expect(!list.contains(URL(filePath: "/Users/pat/Library/Caches/keeper"), home: home))
        #expect(list.contains(URL(filePath: "/Users/pat/Library/Logs/MacPat/actions.jsonl"), home: home))
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

final class Commands: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [Command] = []
    var all: [Command] { lock.withLock { stored } }
    func add(_ c: Command) { lock.withLock { stored.append(c) } }
}

final class Log: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [URL] = []
    var urls: [URL] { lock.withLock { stored } }
    func add(_ url: URL) { lock.withLock { stored.append(url) } }
}

@Suite struct DocTests {
    /// The commands page must name every program MacPat can run.
    @Test func commandsPageListsEveryTool() throws {
        let root = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let page = try String(contentsOf: root.appending(path: "docs/reference/commands.md"), encoding: .utf8)
        for tool in Tool.allCases { #expect(page.contains(tool.rawValue), "\(tool.rawValue) missing from commands.md") }
    }
}

struct StopTests {
    @Test func stopBetweenStepsLeavesTheRestUnrun() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "macpat-stop-\(UUID().uuidString)").resolvingSymlinksInPath()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let files = try (0..<4).map { i -> URL in
            let url = root.appending(path: "f\(i)")
            try Data("x".utf8).write(to: url)
            return url
        }
        let steps = files.map { Step(group: "G", title: $0.lastPathComponent, bytes: 1, risk: .safe, reason: "r", action: .trash($0)) }
        let plan = Plan(steps)
        let log = Log()
        let actions = ActionLog(url: root.appending(path: "log/actions.jsonl"))
        let executor = Executor(zones: Zones(roots: [root]), dispose: { log.add($0) }, log: actions)
        let out = executor.run(plan, previewed: plan.fingerprint, dryRun: false) { done, _ in done < 2 }
        #expect(out.count == 2)
        #expect(out.skipped == 2)
        #expect(out.notRun == [steps[2].id, steps[3].id])
        #expect(log.urls.count == 2)
        // The log must not claim the two that never ran.
        let text = try String(contentsOf: actions.url, encoding: .utf8)
        #expect(text.components(separatedBy: "\"done\"").count - 1 == 2)
        #expect(text.components(separatedBy: "\"not run\"").count - 1 == 2)
    }

    @Test func concurrentMapKeepsOrder() {
        #expect(concurrentMap(Array(0..<200)) { $0 * 2 } == (0..<200).map { $0 * 2 })
        #expect(concurrentMap([Int]()) { $0 }.isEmpty)
    }
}
