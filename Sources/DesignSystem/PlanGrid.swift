// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Patrick Saade

import AppKit
import MacPatCore
import SwiftUI

/// Which grid columns fit. Check, Name, Size, and Verdict always stay.
struct Columns: Equatable {
    let path: Bool
    let modified: Bool
    let bar: Bool

    init(width: CGFloat) {
        path = width >= 780
        modified = width >= 640
        bar = width >= 520
    }
}

/// What a step's menu and the detail pane can do. One place, so both stay the same.
@MainActor enum StepActions {
    static func reveal(_ url: URL) { NSWorkspace.shared.activateFileViewerSelecting([url]) }

    static func openFile(_ step: Step) {
        if let file = step.facts.first(where: { $0.label == "File" }) { NSWorkspace.shared.open(URL(filePath: file.value)) }
    }

    static func copyCommand(_ step: Step) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(step.display, forType: .string)
    }
}

/// The table layout for a plan: ruled rows and columns, groups you can fold, sortable headers,
/// and a detail pane. The pane sits beside the table, or under it when the window is narrow.
struct PlanGrid: View {
    @Bindable var model: PlanModel
    let empty: String
    @State private var total: CGFloat = 1000
    @FocusState private var focused: Bool

    private var pane: Bool { model.paneOpen && model.selectedStep != nil }
    private var stacked: Bool { total < 900 }

    var body: some View {
        let layout = stacked ? AnyLayout(VStackLayout(spacing: 0)) : AnyLayout(HStackLayout(spacing: 0))
        layout {
            table
            if pane, let step = model.selectedStep {
                if !stacked { RetroRule(thickness: 2).frame(width: 2).fixedSize().frame(maxHeight: .infinity) }
                DetailPane(model: model, step: step)
                    .frame(width: stacked ? nil : 340, height: stacked ? 240 : nil)
                    .slides(from: stacked ? .bottom : .trailing)
            }
        }
        .motion(Motion.spring, value: pane)
        .onGeometryChange(for: CGFloat.self) {
            $0.size.width
        } action: {
            total = $0
        }
    }

    private var table: some View {
        GeometryReader { geo in
            let width = geo.size.width - 24
            let columns = Columns(width: pane && !stacked ? width : width)
            VStack(spacing: 0) {
                header(columns)
                RetroScroll {
                    ScrollViewReader { proxy in
                        LazyVStack(spacing: 0) {
                            if model.scanned && model.steps.isEmpty {
                                VStack(spacing: 8) {
                                    PatMascot(.idle).frame(width: 72, height: 72)
                                    Text(empty)
                                }
                                .padding(24).frame(maxWidth: .infinity)
                            }
                            let largest = model.largestBytes
                            ForEach(model.sortedGroups, id: \.name) { group in
                                GridGroup(model: model, name: group.name, steps: group.steps, largest: largest, columns: columns)
                            }
                        }
                        .onChange(of: model.selected) { _, id in
                            if let id { withAnimation(Motion.quick) { proxy.scrollTo(id) } }
                        }
                    }
                }
            }
        }
        .disabled(model.scanning)
        .focusable()
        .focused($focused)
        .focusEffectDisabled()
        // A click on a row doesn't focus anything on its own, so keys would go nowhere. Take focus here.
        .onAppear { focused = true }
        .onChange(of: model.selected) { focused = true }
        .onKeyPress(.upArrow) {
            model.moveSelection(by: -1); return .handled
        }
        .onKeyPress(.downArrow) {
            model.moveSelection(by: 1); return .handled
        }
        .onKeyPress(.space) {
            guard let step = model.selectedStep else { return .ignored }
            model.toggle(step)
            return .handled
        }
        .onKeyPress(.return) {
            guard model.selectedStep != nil else { return .ignored }
            model.paneOpen = true
            return .handled
        }
        .onKeyPress(.escape) {
            guard model.paneOpen else { return .ignored }
            model.paneOpen = false
            return .handled
        }
        .overlay {
            if focused { Rectangle().strokeBorder(Retro.ink, style: StrokeStyle(lineWidth: 1, dash: [1, 3])).allowsHitTesting(false) }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Steps")
    }

    private func header(_ c: Columns) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Color.clear.frame(width: Cell.check, height: 1)
                head("Name", .name).cell(flex: Cell.name)
                if c.path { Text("Path").bold().cell(flex: Cell.path) }
                head("Size", .size).cell(width: Cell.size)
                if c.bar { Text("Bar").bold().cell(width: Cell.bar) }
                if c.modified { head("Modified", .modified).cell(width: Cell.modified) }
                head("Verdict", .verdict).cell(width: Cell.verdict)
            }
            .frame(minHeight: 30)
            .padding(.trailing, 19)  // the scrollbar below is 16 wide plus its 3 pt edge
            RetroRule(thickness: 3)
        }
    }

    private func head(_ title: String, _ key: SortKey) -> some View {
        Button {
            model.sort(by: key)
        } label: {
            HStack(spacing: 4) {
                Text(title).bold()
                if model.sortKey == key { Text(model.sortAscending ? "▴" : "▾").accessibilityHidden(true) }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Sort by \(title)")
        .accessibilityValue(model.sortKey == key ? (model.sortAscending ? "Ascending" : "Descending") : "")
    }
}

private enum Cell {
    static let check: CGFloat = 34
    static let name: CGFloat = 150
    static let path: CGFloat = 120
    static let size: CGFloat = 92
    static let bar: CGFloat = 80
    static let modified: CGFloat = 112
    static let verdict: CGFloat = 100
}

extension View {
    /// A grid cell with a hairline on its left edge.
    fileprivate func cell(width: CGFloat) -> some View {
        padding(.horizontal, 8).frame(width: width, alignment: .leading).modifier(Hairline())
    }

    fileprivate func cell(flex min: CGFloat) -> some View {
        padding(.horizontal, 8).frame(minWidth: min, maxWidth: .infinity, alignment: .leading).modifier(Hairline())
    }
}

private struct Hairline: ViewModifier {
    func body(content: Content) -> some View {
        content.overlay(alignment: .leading) { Rectangle().fill(Retro.ink).frame(width: 1) }
    }
}

private struct GridGroup: View {
    @Bindable var model: PlanModel
    let name: String
    let steps: [Step]
    let largest: Int64
    let columns: Columns

    private var open: Bool { model.expanded.contains(name) }

    var body: some View {
        LazyVStack(spacing: 0) {
            groupRow
            RetroRule(thickness: 1)
            if open {
                ForEach(steps) { step in
                    GridRow(model: model, step: step, largest: largest, columns: columns)
                    RetroRule(thickness: 1)
                }
                .transition(.opacity)
            }
        }
        .clipped()
        .motion(Motion.spring, value: open)
    }

    private var groupRow: some View {
        let bytes = steps.reduce(0) { $0 + $1.bytes }
        let state = model.groupState(name)
        return HStack(spacing: 0) {
            Toggle(isOn: Binding(get: { state == true }, set: { _ in model.toggleGroup(name) })) { EmptyView() }
                .labelsHidden()
                .disabled(steps.allSatisfy { $0.risk == .locked })
                .accessibilityLabel(name)
                .accessibilityValue(state.map { $0 ? "All on" : "Off" } ?? "Some on")
                .frame(width: Cell.check)
            Button {
                if open { model.expanded.remove(name) } else { model.expanded.insert(name) }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.right").rotationEffect(.degrees(open ? 90 : 0)).frame(width: 14)
                        .motion(Motion.spring, value: open)
                    Text(name).bold().lineLimit(1).truncationMode(.tail)
                    if state == nil { Text("(some)") }
                    Text("\(steps.count)").foregroundStyle(Retro.ink.opacity(0.7))
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(open ? "Hide \(name) steps" : "Show \(name) steps")
            .cell(flex: Cell.name + (columns.path ? Cell.path : 0))
            Text(bytes > 0 ? ByteFormat.string(bytes) : "").monospacedDigit().bold().frame(maxWidth: .infinity, alignment: .trailing)
                .cell(width: Cell.size)
            if columns.bar {
                Group { if largest > 0 { Bar(fraction: Double(bytes) / Double(largest)).frame(height: 10) } }.cell(width: Cell.bar)
            }
            if columns.modified { Color.clear.cell(width: Cell.modified) }
            RiskBadge(risk: steps.map(\.risk).max(by: { $0.rank < $1.rank }) ?? .safe).cell(width: Cell.verdict)
        }
        .frame(minHeight: 36)
    }
}

private struct GridRow: View {
    @Bindable var model: PlanModel
    let step: Step
    let largest: Int64
    let columns: Columns

    private static let relative: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        f.dateTimeStyle = .named
        return f
    }()

    private var selected: Bool { model.selected == step.id }

    /// Name, size, and verdict in one breath, so VoiceOver doesn't read three separate cells.
    private var rowLabel: String {
        [
            step.title, step.bytes > 0 ? ByteFormat.string(step.bytes) : nil, step.risk.word.lowercased(),
            step.needsAdmin ? "needs admin" : nil,
        ]
        .compactMap { $0 }.joined(separator: ", ")
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Toggle(isOn: Binding(get: { model.isOn(step) }, set: { _ in model.toggle(step) })) { EmptyView() }
                    .labelsHidden()
                    .disabled(step.risk == .locked)
                    .accessibilityLabel(step.title)
                    .frame(width: Cell.check)
                Button {
                    model.select(step, openPane: true)
                } label: {
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 4) {
                            Text(step.title).bold().lineLimit(1).truncationMode(.middle)
                            if step.needsAdmin { Image(systemName: "lock.shield").accessibilityLabel("Needs admin") }
                        }
                        Text(step.reason).font(.caption.monospaced()).lineLimit(1).truncationMode(.tail)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(rowLabel)
                .accessibilityHint("Opens the detail pane")
                .cell(flex: Cell.name)
                if columns.path {
                    Text(step.url.map(PathFormat.short) ?? step.fact("File") ?? step.fact("Program") ?? "").font(.callout.monospaced())
                        .lineLimit(1).truncationMode(.middle)
                        .cell(flex: Cell.path)
                }
                Text(step.bytes > 0 ? ByteFormat.string(step.bytes) : "").monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .trailing).cell(width: Cell.size)
                if columns.bar {
                    Group { if step.bytes > 0, largest > 0 { Bar(fraction: Double(step.bytes) / Double(largest)).frame(height: 10) } }
                        .cell(width: Cell.bar)
                }
                if columns.modified {
                    Text(
                        model.modified[step.id].map { Self.relative.localizedString(for: $0, relativeTo: .now) }
                            ?? step.fact("Modified") ?? step.fact("Plist changed") ?? "—"
                    )
                    .font(.callout.monospaced()).lineLimit(1).cell(width: Cell.modified)
                }
                RiskBadge(risk: step.risk).cell(width: Cell.verdict)
            }
            .frame(minHeight: 40)
            if model.showCommands {
                Text("$ " + step.display).font(.callout.monospaced()).textSelection(.enabled).padding(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(Rectangle().strokeBorder(Retro.ink, style: StrokeStyle(lineWidth: 1, dash: [2, 2])))
                    .padding(.horizontal, Cell.check).padding(.bottom, 8)
            }
            if let failure = model.outcome?.failure(for: step) {
                Text("✗ " + failure).bold().font(.callout.monospaced()).padding(.horizontal, Cell.check).padding(.bottom, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .id(step.id)
        .background(selected ? Retro.paper : Color.clear)
        .overlay { if selected { Ants() } }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .contextMenu {
            if let url = step.url {
                Button("Reveal in Finder") { StepActions.reveal(url) }
                Button("Never Touch This") { model.neverTouch(step) }
            }
            if step.facts.contains(where: { $0.label == "File" }) { Button("Open File") { StepActions.openFile(step) } }
            Button("Copy Command") { StepActions.copyCommand(step) }
        }
    }
}

/// A dashed outline that steps along, so the chosen row is more than a color. Still under Reduce Motion.
private struct Ants: View {
    @Environment(\.accessibilityReduceMotion) private var reduce

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.4)) { context in
            let flip = !reduce && Int(context.date.timeIntervalSinceReferenceDate / 0.4) % 2 == 0
            Rectangle()
                .strokeBorder(Retro.ink, style: StrokeStyle(lineWidth: 2, dash: [6, 3], dashPhase: flip ? 3 : 0))
                .padding(2)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Everything about one step: full path, reason, every fact, the command, and what you can do with it.
struct DetailPane: View {
    @Bindable var model: PlanModel
    let step: Step

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Detail").bold().accessibilityAddTraits(.isHeader)
                Spacer()
                Button("Close") { model.paneOpen = false }.keyboardShortcut(.escape, modifiers: [])
            }
            .padding(10)
            RetroRule()
            RetroScroll {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(step.title).bold().textSelection(.enabled)
                        Spacer()
                        RiskBadge(risk: step.risk)
                    }
                    if let url = step.url {
                        Text(url.path).font(.callout.monospaced()).textSelection(.enabled)
                            .padding(6).frame(maxWidth: .infinity, alignment: .leading)
                            .overlay(Rectangle().strokeBorder(Retro.ink, style: StrokeStyle(lineWidth: 1, dash: [2, 2])))
                    }
                    Text(step.reason).font(.callout.monospaced()).fixedSize(horizontal: false, vertical: true)
                    if step.bytes > 0 { fact("Size", ByteFormat.string(step.bytes)) }
                    if let date = model.modified[step.id], !step.facts.contains(where: { $0.label == "Modified" }) {
                        fact("Modified", date.formatted(date: .abbreviated, time: .shortened))
                    }
                    ForEach(step.facts, id: \.self) { fact($0.label, $0.value) }
                    Text("$ " + step.display).font(.callout.monospaced()).textSelection(.enabled)
                        .padding(6).frame(maxWidth: .infinity, alignment: .leading)
                        .overlay(Rectangle().strokeBorder(Retro.ink, style: StrokeStyle(lineWidth: 1, dash: [2, 2])))
                    if let failure = model.outcome?.failure(for: step) { Text("✗ " + failure).bold().font(.callout.monospaced()) }
                    actions
                }
                .padding(12)
            }
        }
        .background(Retro.paper)
    }

    private func fact(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(label + ":").font(.callout.monospaced()).bold()
            Text(value).font(.callout.monospaced()).textSelection(.enabled)
        }
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let url = step.url {
                Button("Reveal in Finder") { StepActions.reveal(url) }
                Button("Never Touch This") {
                    model.neverTouch(step)
                    model.paneOpen = false
                }
            }
            if step.facts.contains(where: { $0.label == "File" }) { Button("Open File") { StepActions.openFile(step) } }
            Button("Copy Command") { StepActions.copyCommand(step) }
        }
    }
}

extension Step {
    /// The value of the first fact with this label.
    fileprivate func fact(_ label: String) -> String? { facts.first { $0.label == label }?.value }
}
