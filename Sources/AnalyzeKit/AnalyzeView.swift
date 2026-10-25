// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Patrick Saade

import AppKit
import DesignSystem
import MacPatCore
import SwiftUI

public struct AnalyzeModule: MacPatModule {
    public let id = "analyze"
    public let title = "Analyze"
    public let symbol = "chart.bar.xaxis"

    public init() {}

    public func makeView() -> AnyView { AnyView(AnalyzeView()) }
}

struct AnalyzeView: View {
    enum Tab: String, CaseIterable { case space = "Space", large = "Large and old" }

    private let home = FileManager.default.homeDirectoryForCurrentUser
    @State private var tab = Tab.space
    @State private var summary: VolumeSummary?
    @State private var path: [URL] = [FileManager.default.homeDirectoryForCurrentUser]
    @State private var entries: [Entry] = []
    @State private var sizing = false
    @State private var basket: [Entry] = []
    @State private var model: PlanModel

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        _model = State(
            initialValue: PlanModel(executor: Executor(zones: LargeOldScanner.zones(home: home), home: home, log: .standard(home: home))) {
                LargeOldScanner(home: home).steps()
            })
    }

    private var demo = false

    init(demo summary: VolumeSummary, entries: [Entry], model: PlanModel, tab: Tab = .space) {
        _summary = State(initialValue: summary)
        _entries = State(initialValue: entries)
        _model = State(initialValue: model)
        _tab = State(initialValue: tab)
        _path = State(initialValue: [URL(filePath: "/Users/pat")])
        demo = true
    }

    var body: some View {
        VStack(spacing: 0) {
            summaryBox
            RetroRule(thickness: 1)
            RetroSegments("View", options: Tab.allCases.map { ($0, $0.rawValue) }, selection: $tab).padding(8)
            RetroRule(thickness: 1)
            switch tab {
            case .space: folders
            case .large: PlanView(model: model, empty: "No files over 500 MB that sat unopened for 180 days.")
            }
        }
        .task { if !demo { summary = await Task.detached { VolumeSummary.read() }.value } }
        .task(id: path) { if !demo { await size() } }
    }

    @ViewBuilder private var summaryBox: some View {
        if let s = summary {
            VStack(alignment: .leading, spacing: 6) {
                Bar(fraction: s.total > 0 ? Double(s.used) / Double(s.total) : 0).frame(height: 14)
                    .accessibilityLabel("Disk used").accessibilityValue("\(Int(Double(s.used) / Double(max(s.total, 1)) * 100)) percent")
                Text("\(ByteFormat.string(s.used)) used of \(ByteFormat.string(s.total)). \(ByteFormat.string(s.free)) free.")
                Text(
                    "Plus \(ByteFormat.string(s.purgeable)) macOS can purge on its own. \(s.snapshots.count) local Time Machine snapshots hold deleted files until they expire. That's why freed space can take a while to show up."
                )
                .font(.callout.monospaced()).fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
        } else {
            Text("Reading the disk…").padding(12)
        }
    }

    private var folders: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Up") { path.removeLast() }.disabled(path.count < 2)
                Text(PathFormat.short(path.last!)).bold().lineLimit(1).truncationMode(.head)
                Spacer()
                if !basket.isEmpty {
                    Button("Review \(basket.count) in Plan") { tab = .large }
                }
            }
            .padding(8)
            RetroRule(thickness: 1)
            ScrollView {
                VStack(spacing: 0) {
                    let top = max(entries.first?.bytes ?? 1, 1)
                    ForEach(entries) { entry in
                        row(entry, top: top)
                        RetroRule(thickness: 1).opacity(0.3)
                    }
                }
            }
            .overlay { if sizing { Text("Sizing…").padding(8).background(Retro.paper).border(Retro.ink, width: Retro.line) } }
            Text("Allocated sizes. APFS clones are counted in full each time, so totals can run high.")
                .font(.caption.monospaced()).padding(6)
        }
    }

    private func row(_ entry: Entry, top: Int64) -> some View {
        Button {
            if entry.isFolder { path.append(entry.url) }
        } label: {
            HStack {
                Image(systemName: entry.isFolder ? "folder" : "doc").frame(width: 16).accessibilityHidden(true)
                Text(entry.url.lastPathComponent).lineLimit(1)
                Spacer()
                Bar(fraction: Double(entry.bytes) / Double(top)).frame(width: 120, height: 10).accessibilityHidden(true)
                Text(ByteFormat.string(entry.bytes)).monospacedDigit().frame(width: 90, alignment: .trailing)
            }
            .padding(.horizontal, 12).padding(.vertical, 5).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(entry.url.lastPathComponent), \(ByteFormat.string(entry.bytes))\(entry.isFolder ? ", folder" : "")")
        .contextMenu {
            Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([entry.url]) }
            Button("Add to Trash Plan") { add(entry) }
                .disabled((try? LargeOldScanner.zones(home: home).validate(entry.url)) == nil)
        }
    }

    private func add(_ entry: Entry) {
        guard !basket.contains(entry) else { return }
        basket.append(entry)
        let (home, basket) = (home, basket)
        model.setSource {
            let picked = basket.map {
                Step(
                    group: "Picked in Space view", title: $0.url.lastPathComponent, bytes: $0.bytes, risk: .review,
                    reason: "You picked this. MacPat knows nothing else about it.", action: .trash($0.url), preselected: false)
            }
            return picked + LargeOldScanner(home: home).steps()
        }
    }

    private func size() async {
        sizing = true
        entries = await FolderSizer.children(of: path.last!)
        sizing = false
    }
}
