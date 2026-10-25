// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Patrick Saade

import Foundation
import MacPatCore
import Testing

@testable import CleanKit

@Suite struct RuleTests {
    let home = FileManager.default.temporaryDirectory.appending(path: "macpat-rules-\(UUID().uuidString)")

    func load(_ json: String?) throws -> [Target] {
        let dir = home.appending(path: "rules")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }
        if let json { try json.write(to: dir.appending(path: "r.json"), atomically: true, encoding: .utf8) }
        return try RuleLoader.load(from: dir, home: home, zones: Zones(home: home))
    }

    func rule(id: String = "ok", paths: String = #"["~/Library/Caches"]"#) -> String {
        #"{"id":"\#(id)","name":"N","summary":"S","risk":"safe","paths":\#(paths)}"#
    }

    @Test func bundledRulesAreValid() throws {
        let real = FileManager.default.homeDirectoryForCurrentUser
        let targets = try RuleLoader.load(from: RuleLoader.bundledDirectory, home: real, zones: Zones(home: real))
        #expect(targets.count >= 25)
        #expect(Set(targets.map(\.group)).count >= 5)
    }

    @Test func acceptsGoodRule() throws {
        #expect(try load(rule()).map(\.id) == ["ok"])
    }

    @Test(arguments: [
        #"["~/Documents"]"#, #"["~/"]"#, #"["/System/Library"]"#, #"["~/Library/Caches/../../Documents"]"#,
        #"["Library/Caches"]"#, #"[]"#, #"["~/Library"]"#,
    ])
    func rejectsUnsafePaths(paths: String) {
        #expect(throws: RuleError.self) { try load(rule(paths: paths)) }
    }

    @Test(arguments: ["", "Bad Id", "UPPER", "a/b", "../x"])
    func rejectsBadIds(id: String) {
        #expect(throws: RuleError.self) { try load(rule(id: id)) }
    }

    @Test(arguments: [
        #"{"id":"x","name":"N","summary":"S","risk":"locked","paths":["~/Library/Caches"]}"#,
        #"{"id":"x","name":"N","summary":"S","risk":"safe","paths":["~/Library/Caches"],"scope":"root"}"#,
        #"{"id":"x","name":"N","summary":"S","risk":"safe","paths":["/System/Library"],"scope":"system"}"#,
        #"{"id":"x","name":"N","summary":"S","risk":"safe","paths":["/Library"],"scope":"system"}"#,
        #"{"id":"x","name":"N","summary":"S","risk":"safe","paths":[],"command":"rm-rf"}"#,
        #"{"id":"x","name":"N","summary":"S","risk":"safe","paths":["~/Library/Caches"],"match":["../*"]}"#,
        #"{"id":"x","name":"N","summary":"S","risk":"safe","paths":["~/Library/Caches"],"minAgeDays":-1}"#,
        #"{"id":"x","name":"N","summary":"S","risk":"review","paths":["~/Library/Caches"],"preselect":true}"#,
        #"{"id":"x","name":"N","summary":"S","risk":"safe","paths":["~/Library/Caches"],"details":"anything"}"#,
    ])
    func rejectsBadV2Fields(json: String) {
        #expect(throws: RuleError.self) { try load(json) }
    }

    @Test func acceptsSystemAndCommandRules() throws {
        let system = try load(#"{"id":"x","name":"N","summary":"S","risk":"review","paths":["/Library/Caches"],"scope":"system"}"#)
        #expect(system.first?.system == true)
        let command = try load(#"{"id":"x","name":"N","summary":"S","risk":"safe","paths":[],"command":"simctl-delete-unavailable"}"#)
        #expect(command.first?.command == .deleteUnavailableSimulators())
    }

    @Test func rejectsGarbage() {
        #expect(throws: RuleError.self) { try load("{not json") }
    }
}
