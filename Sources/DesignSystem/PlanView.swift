// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Patrick Saade

import AppKit
import MacPatCore
import SwiftUI
import UniformTypeIdentifiers

/// The preview breakdown every module shares: groups, steps, reasons, facts, and the
/// exact command each step stands for. Run stays locked until a preview of this exact choice.
public struct PlanView<Header: View>: View {
    @Bindable var model: PlanModel
    let runLabel: String
    let empty: String
    let header: Header
    @State private var confirming = false

    public init(
        model: PlanModel, runLabel: String = "Move to Trash…", empty: String = "Nothing found.",
        @ViewBuilder header: () -> Header = { EmptyView() }
    ) {
        self.model = model
        self.runLabel = runLabel
        self.empty = empty
        self.header = header()
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            banners
            list
            RetroRule()
            footer
        }
        .task { if !model.scanned { await model.scan() } }
    }

    @ViewBuilder private var banners: some View {
        if let out = model.outcome {
            if let refused = out.refused {
                RetroBanner(.warning, refused)
            } else if out.dryRun {
                RetroBanner(.dryRun, "Nothing changed. \(summary(out, verb: "Would do"))")
            } else {
                RetroBanner(.info, "\(summary(out, verb: "Done")) Look in the Trash to put anything back.")
            }
        }
        if model.adminCount > 0 {
            RetroBanner(.admin, "\(model.adminCount) chosen steps need admin. macOS will ask for your password.")
        }
    }

    private func summary(_ out: Outcome, verb: String) -> String {
        let failed = out.failures.isEmpty ? "" : " \(out.failures.count) would fail, see below."
        return "\(verb): \(Count.steps(out.count))\(out.bytes > 0 ? ", " + ByteFormat.string(out.bytes) : "").\(failed)"
    }

    private var list: some View {
        ScrollView {
            VStack(spacing: 0) {
                if model.scanned && model.steps.isEmpty {
                    Text(empty).padding(24).frame(maxWidth: .infinity)
                }
                let largest = model.groups.map { $0.steps.reduce(Int64(0)) { $0 + $1.bytes } }.max() ?? 0
                ForEach(model.groups, id: \.name) { group in
                    GroupSection(model: model, name: group.name, steps: group.steps, largest: largest)
                    RetroRule(thickness: 1)
                }
            }
        }
        .overlay {
            if model.scanning {
                Text("Scanning…").padding(8).background(Retro.paper).border(Retro.ink, width: Retro.line)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Text(status).lineLimit(2).layoutPriority(-1)
            Spacer(minLength: 8)
            Toggle("Show commands", isOn: $model.showCommands)
                .help("Show the shell line each step stands for.")
            Menu("Export") {
                Button("Copy as Script") { copyScript() }
                Button("Save Plan as JSON…") { saveJSON() }
            }
            .menuStyle(.button)
            .fixedSize()
            .disabled(model.chosen.isEmpty)
            Button("Scan") { Task { await model.scan() } }
                .disabled(model.scanning || model.working)
                .help("Look again. Nothing is changed.")
            Button("Preview") { Task { await model.preview() } }
                .disabled(model.chosen.isEmpty || model.working)
                .keyboardShortcut("p")
                .help("A dry run. Checks every step and changes nothing.")
            Button(runLabel) { confirming = true }
                .fixedSize()
                .disabled(model.previewed == nil || model.working)
                .help("Preview first. Then this unlocks.")
        }
        .padding(12)
        .confirmationDialog("Run \(model.chosen.count) steps?", isPresented: $confirming, titleVisibility: .visible) {
            Button(runLabel.replacingOccurrences(of: "…", with: ""), role: .destructive) { Task { await model.run() } }
        } message: {
            Text("\(ByteFormat.string(model.chosenBytes)) in total. Files go to the Trash. \(model.adminCount) steps ask for admin.")
        }
    }

    private var status: String {
        if model.chosen.isEmpty { return model.scanned ? "Pick what to include." : "" }
        let lock = model.previewed == nil ? "Preview to unlock." : "Previewed."
        let size = model.chosenBytes > 0 ? ", \(ByteFormat.string(model.chosenBytes))" : ""
        return "\(model.chosen.count) chosen\(size). \(lock)"
    }

    private func copyScript() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(model.plan.script(), forType: .string)
    }

    private func saveJSON() {
        guard let data = try? model.plan.json() else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "macpat-plan.json"
        if panel.runModal() == .OK, let url = panel.url { try? data.write(to: url) }
    }
}

private struct GroupSection: View {
    @Bindable var model: PlanModel
    let name: String
    let steps: [Step]
    let largest: Int64

    private var open: Bool { model.expanded.contains(name) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Toggle(isOn: Binding(get: { model.groupState(name) == true }, set: { _ in model.toggleGroup(name) })) {
                    Text(name).bold()
                }
                .disabled(steps.allSatisfy { $0.risk == .locked })
                .accessibilityValue(model.groupState(name).map { $0 ? "All on" : "Off" } ?? "Some on")
                if model.groupState(name) == nil { Text("(some)").accessibilityHidden(true) }
                Spacer()
                let bytes = steps.reduce(0) { $0 + $1.bytes }
                if largest > 0 { Bar(fraction: Double(bytes) / Double(largest)).frame(width: 90, height: 10) }
                Text(bytes > 0 ? "\(steps.count) · \(ByteFormat.string(bytes))" : "\(steps.count)").monospacedDigit()
                RiskBadge(risk: steps.map(\.risk).max(by: { $0.rank < $1.rank }) ?? .safe)
                Button {
                    if open { model.expanded.remove(name) } else { model.expanded.insert(name) }
                } label: {
                    Image(systemName: open ? "chevron.down" : "chevron.right").frame(width: 14)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(open ? "Hide \(name) steps" : "Show \(name) steps")
            }
            .padding(12)
            if open {
                ForEach(steps) { step in
                    RetroRule(thickness: 1).opacity(0.4)
                    StepRow(model: model, step: step)
                }
            }
        }
    }
}

private struct StepRow: View {
    @Bindable var model: PlanModel
    let step: Step

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Toggle(isOn: Binding(get: { model.isOn(step) }, set: { _ in model.toggle(step) })) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(step.title).bold()
                        if step.needsAdmin { Image(systemName: "lock.shield").accessibilityLabel("Needs admin") }
                        Spacer()
                        if step.bytes > 0 { Text(ByteFormat.string(step.bytes)).monospacedDigit() }
                        RiskBadge(risk: step.risk)
                    }
                    if let url = step.url { Text(PathFormat.short(url)).font(.callout.monospaced()).textSelection(.enabled) }
                    Text(step.reason).font(.callout.monospaced()).fixedSize(horizontal: false, vertical: true)
                    ForEach(step.facts, id: \.self) { fact in
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(fact.label + ":").font(.callout.monospaced()).bold()
                            Text(fact.value).font(.callout.monospaced()).textSelection(.enabled)
                        }
                    }
                    if model.showCommands {
                        Text("$ " + step.display)
                            .font(.callout.monospaced())
                            .textSelection(.enabled)
                            .padding(4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .overlay(Rectangle().strokeBorder(Retro.ink, style: StrokeStyle(lineWidth: 1, dash: [2, 2])))
                    }
                    if let failure = model.outcome?.failure(for: step) {
                        Text("✗ " + failure).bold().font(.callout.monospaced())
                    }
                }
                .contentShape(Rectangle())
            }
            .disabled(step.risk == .locked)
        }
        .padding(.leading, 34)
        .padding([.trailing, .vertical], 10)
        .contextMenu {
            if let url = step.url {
                Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                Button("Never Touch This") { model.neverTouch(step) }
            }
            if let file = step.facts.first(where: { $0.label == "File" }) {
                Button("Open File") { NSWorkspace.shared.open(URL(filePath: file.value)) }
            }
            Button("Copy Command") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(step.display, forType: .string)
            }
        }
    }
}

/// The risk as a word and a glyph. Review is inverted so it stands out without color.
public struct RiskBadge: View {
    let risk: Risk

    public init(risk: Risk) { self.risk = risk }

    public var body: some View {
        let inverted = risk == .review
        HStack(spacing: 3) {
            Image(systemName: risk.symbol).accessibilityHidden(true)
            Text(risk.word)
        }
        .font(.caption.monospaced().bold())
        .padding(.horizontal, 5)
        .padding(.vertical, 1)
        .foregroundStyle(inverted ? Retro.paper : Retro.ink)
        .background(inverted ? Retro.ink : Retro.paper)
        .overlay(Rectangle().strokeBorder(Retro.ink, style: StrokeStyle(lineWidth: 1, dash: risk == .locked ? [2, 2] : [])))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Risk: \(risk.word)")
    }
}

extension Risk {
    public var word: String {
        switch self {
        case .safe: "SAFE"
        case .review: "REVIEW"
        case .locked: "LOCKED"
        }
    }

    var symbol: String {
        switch self {
        case .safe: "checkmark"
        case .review: "exclamationmark"
        case .locked: "lock"
        }
    }

    var rank: Int { Risk.allCases.firstIndex(of: self)! }
}

enum Count {
    static func steps(_ n: Int) -> String { n == 1 ? "1 step" : "\(n) steps" }
}

public enum PathFormat {
    /// `~/…` for paths in the home folder.
    public static func short(_ url: URL) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if url.path == home { return "~" }
        if url.path.hasPrefix(home + "/") { return "~" + url.path.dropFirst(home.count) }
        return url.path.replacing(/^\/Users\/[^\/]+(\/|$)/, with: "~/")
    }
}
