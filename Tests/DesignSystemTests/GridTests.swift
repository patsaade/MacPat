// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Patrick Saade

import Foundation
import MacPatCore
import Testing

@testable import DesignSystem

@MainActor
struct GridTests {
    private func step(_ title: String, _ bytes: Int64, _ risk: Risk = .safe, group: String = "A") -> Step {
        Step(group: group, title: title, bytes: bytes, risk: risk, reason: "r", action: .none, id: title)
    }

    private func model(_ steps: [Step]) async -> PlanModel {
        let model = PlanModel(
            executor: Executor(zones: Zones(roots: []), home: URL(filePath: "/Users/pat"), dispose: { _ in }, runner: .none)
        ) {
            steps
        }
        await model.scan()
        return model
    }

    @Test func sizeSortsDescendingByDefault() async {
        let m = await model([step("a", 1), step("b", 3), step("c", 2)])
        #expect(m.sortedGroups[0].steps.map(\.title) == ["b", "c", "a"])
    }

    @Test func sameColumnFlipsAndNewColumnResets() async {
        let m = await model([step("b", 1), step("a", 2)])
        m.sort(by: .size)
        #expect(m.sortAscending)
        m.sort(by: .name)
        #expect(m.sortKey == .name && m.sortAscending)
        #expect(m.sortedGroups[0].steps.map(\.title) == ["a", "b"])
        m.sort(by: .verdict)
        #expect(!m.sortAscending)
    }

    @Test func sortStaysInsideGroups() async {
        let m = await model([step("x", 1, group: "A"), step("y", 9, group: "B"), step("z", 5, group: "A")])
        #expect(m.sortedGroups.map(\.name) == ["A", "B"])
        #expect(m.sortedGroups[0].steps.map(\.title) == ["z", "x"])
    }

    @Test func verdictSortPutsLockedLast() {
        let steps = [step("a", 1, .locked), step("b", 1, .safe), step("c", 1, .review)]
        let sorted = PlanModel.order(steps, by: .verdict, ascending: true, modified: [:])
        #expect(sorted.map(\.risk) == [.safe, .review, .locked])
    }

    @Test func modifiedSortUsesDates() {
        let steps = [step("old", 1), step("new", 1), step("none", 1)]
        let dates = ["old": Date(timeIntervalSince1970: 10), "new": Date(timeIntervalSince1970: 20)]
        let sorted = PlanModel.order(steps, by: .modified, ascending: false, modified: dates)
        #expect(sorted.map(\.title) == ["new", "old", "none"])
    }

    @Test func arrowKeysMoveOverVisibleRowsOnly() async {
        let m = await model([step("a", 3, group: "A"), step("b", 2, group: "A"), step("c", 1, group: "B")])
        m.expanded = ["A"]
        m.moveSelection(by: 1)
        #expect(m.selected == "a")
        m.moveSelection(by: 1)
        m.moveSelection(by: 1)
        #expect(m.selected == "b")
        m.moveSelection(by: -5)
        #expect(m.selected == "a")
    }

    @Test func selectingOpensPaneOnlyWhenAsked() async {
        let m = await model([step("a", 1)])
        m.select(m.steps[0], openPane: false)
        #expect(m.selected == "a" && !m.paneOpen)
        m.select(m.steps[0], openPane: true)
        #expect(m.paneOpen)
    }

    @Test func narrowWindowsDropPathThenModifiedThenBar() {
        #expect(Columns(width: 900) == Columns(width: 800))
        let wide = Columns(width: 900)
        #expect(wide.path && wide.modified && wide.bar)
        let mid = Columns(width: 700)
        #expect(!mid.path && mid.modified && mid.bar)
        let small = Columns(width: 600)
        #expect(!small.path && !small.modified && small.bar)
        let tiny = Columns(width: 400)
        #expect(!tiny.path && !tiny.modified && !tiny.bar)
    }

    @Test func markDrawsSomethingAtEveryLift() {
        for lift in [0, 7, 14] as [CGFloat] {
            #expect(!PatMark(lift: lift).path(in: CGRect(x: 0, y: 0, width: 18, height: 18)).isEmpty)
        }
    }
}
