// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Patrick Saade

import AppKit
import MacPatCore
import SwiftUI
import UniformTypeIdentifiers

/// The preview breakdown every module shares: groups, steps, reasons, facts, and the
/// exact command each step stands for. Run stays locked until a preview of this exact choice.
/// A one-time note for a screen: what Scan looks at and that nothing changes until Run. Shown until dismissed.
public struct Intro: Sendable {
    let key: String
    let text: String

    public init(_ key: String, _ text: String) {
        self.key = key
        self.text = text
    }
}

public enum PlanLayout: Sendable {
    /// Tall rows, one step per block.
    case stacked
    /// A table: one line per step, sortable columns, a detail pane.
    case grid
}

public struct PlanView<Header: View>: View {
    @Bindable var model: PlanModel
    let layout: PlanLayout
    let intro: Intro?
    @AppStorage private var introSeen: Bool
    let runLabel: String
    let empty: String
    let header: Header
    @State private var confirming = false

    public init(
        model: PlanModel, layout: PlanLayout = .stacked, intro: Intro? = nil, runLabel: String = "Move to Trash",
        empty: String = "Nothing found.",
        @ViewBuilder header: () -> Header = { EmptyView() }
    ) {
        self.model = model
        self.layout = layout
        self.intro = intro
        _introSeen = AppStorage(wrappedValue: false, "intro.\(intro?.key ?? "none")")
        self.runLabel = runLabel
        self.empty = empty
        self.header = header()
    }

    public var body: some View {
        VStack(spacing: 0) {
            if let intro, !introSeen, !model.forSnapshot {
                RetroBanner(.info, intro.text) { Button("Got It") { introSeen = true } }
            }
            header
            banners
            list
            RetroRule()
            footer
        }
        .task { if !model.scanned { await model.scan() } }
        .focusedSceneValue(\.planActions, active ? actions : nil)
    }

    @Environment(\.moduleActive) private var active

    /// What the Plan menu drives. Only the module on screen offers it.
    private var actions: PlanActions {
        PlanActions(
            scan: { Task { await model.scan() } },
            preview: { Task { await model.preview() } },
            toggleCommands: { model.showCommands.toggle() },
            closeDetail: { model.paneOpen = false },
            canScan: !model.scanning && !model.working,
            canPreview: !model.chosen.isEmpty && !model.working,
            detailOpen: model.paneOpen)
    }

    private var banners: some View {
        VStack(spacing: 0) { bannerItems }
            .motion(Motion.settle, value: model.outcome)
            .motion(Motion.settle, value: model.adminCount)
            .motion(Motion.settle, value: model.scanCancelled)
    }

    @ViewBuilder private var bannerItems: some View {
        if let out = model.outcome {
            if let refused = out.refused {
                RetroBanner(.warning, refused).transition(.opacity.combined(with: .move(edge: .top)))
            } else if out.dryRun {
                RetroBanner(.dryRun, "Nothing changed. \(summary(out, verb: "Would do"))").transition(
                    .opacity.combined(with: .move(edge: .top)))
            } else {
                RetroBanner(.done, doneText(out)) {
                    Button("Open Trash") { NSWorkspace.shared.open(URL.trashDirectory) }
                    Button("Open Log") { NSWorkspace.shared.open(ActionLog.folder(home: FileManager.default.homeDirectoryForCurrentUser)) }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        if model.scanCancelled && !model.scanning {
            RetroBanner(.info, "Scan stopped. This is what it found before then.") {
                Button("Scan Again") { Task { await model.scan() } }
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
        if let touched = model.neverTouched {
            RetroBanner(.info, "\(touched.title) won't show up in scans again. Settings lists everything you marked.") {
                Button("Undo") { Task { await model.undoNeverTouch() } }
                Button("OK") { model.dismissNeverTouched() }
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
        if model.adminCount > 0 {
            RetroBanner(.admin, "\(model.adminCount) chosen steps need admin. macOS will ask for your password.")
                .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    /// What happened, from what ran. Not every step goes to the Trash.
    private func doneText(_ out: Outcome) -> String {
        let moved = model.lastRun.trash
        let ran = model.lastRun.commands
        var parts = [summary(out, verb: "Done")]
        if out.skipped > 0 { parts.append("Stopped. \(Count.steps(out.skipped)) did not run.") }
        if moved > 0 { parts.append("\(moved) went to the Trash. Put them back from there.") }
        if ran > 0 { parts.append("\(ran) ran a command and can't be put back from the Trash.") }
        return parts.joined(separator: " ")
    }

    private func summary(_ out: Outcome, verb: String) -> String {
        let failed = out.failures.isEmpty ? "" : " \(out.failures.count) would fail, see below."
        return "\(verb): \(Count.steps(out.count))\(out.bytes > 0 ? ", " + ByteFormat.string(out.bytes) : "").\(failed)"
    }

    @ViewBuilder private var list: some View {
        switch layout {
        case .grid: PlanGrid(model: model, empty: empty).overlay { scanning }
        case .stacked: stackedList.overlay { scanning }
        }
    }

    @ViewBuilder private var scanning: some View {
        if model.scanning {
            HStack(spacing: 10) {
                PatMascot(.scanning).frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Scanning…")
                    if let progress = model.progress {
                        Text("\(progress.done) of \(progress.total) places").font(.caption.monospaced())
                    }
                }
                Button("Cancel") { model.cancelScan() }
            }
            .padding(10).background(Retro.paper).border(Retro.ink, width: Retro.line)
        }
    }

    private var stackedList: some View {
        RetroScroll {
            VStack(spacing: 0) {
                if model.scanned && model.steps.isEmpty {
                    VStack(spacing: 8) {
                        PatMascot(.idle).frame(width: 72, height: 72)
                        Text(empty)
                    }
                    .padding(24).frame(maxWidth: .infinity)
                }
                let largest = model.groups.map { $0.steps.reduce(Int64(0)) { $0 + $1.bytes } }.max() ?? 0
                ForEach(model.groups, id: \.name) { group in
                    GroupSection(model: model, name: group.name, steps: group.steps, largest: largest)
                    RetroRule(thickness: 1)
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            if let out = model.outcome, !out.dryRun, out.refused == nil, out.failures.isEmpty {
                PatMascot(.done).frame(width: 28, height: 28)
            }
            Text(status).lineLimit(3).layoutPriority(-1)
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
                .help("Look again. Nothing is changed. Command-R.")
            Button("Preview") { Task { await model.preview() } }
                .disabled(model.chosen.isEmpty || model.working)
                .help("A dry run. Checks every item and changes nothing. Shift-Command-P.")
            Button(runTitle) { confirming = true }
                .fixedSize()
                .disabled(model.previewed == nil || model.working)
                .help("Preview first. Then this unlocks.")
        }
        .padding(12)
        .confirmationDialog(confirmTitle, isPresented: $confirming, titleVisibility: .visible) {
            Button(runLabel.replacingOccurrences(of: "…", with: ""), role: .destructive) { Task { await model.run() } }
        } message: {
            Text(confirmMessage)
        }
    }

    /// The run button names the verb and the count: "Move 12 to Trash…".
    private var runTitle: String {
        let verb = runLabel.replacingOccurrences(of: "…", with: "")
        let n = model.chosen.count
        guard n > 0 else { return verb + "…" }
        // "Move to Trash" reads best with the count after the verb: "Move 12 to Trash".
        if let range = verb.range(of: " to ") { return verb[..<range.lowerBound] + " \(n)" + verb[range.lowerBound...] + "…" }
        return "\(verb) \(n)…"
    }

    private var confirmTitle: String {
        let n = Count.steps(model.chosen.count)
        return model.commandCount == 0 ? "Move \(n) to the Trash?" : "Run \(n)?"
    }

    private var confirmMessage: String {
        var lines: [String] = []
        if model.chosenBytes > 0 { lines.append("\(ByteFormat.string(model.chosenBytes)) in total.") }
        if model.trashCount > 0 { lines.append("\(model.trashCount) go to the Trash, where you can put them back.") }
        if model.commandCount > 0 { lines.append("\(model.commandCount) run a command. The Trash can't undo those.") }
        if model.reviewCount > 0 { lines.append("\(model.reviewCount) are marked REVIEW.") }
        if model.adminCount > 0 { lines.append("\(model.adminCount) ask for your password.") }
        let first = model.chosenSteps.prefix(3).map(\.title).joined(separator: ", ")
        if !first.isEmpty { lines.append("Includes " + first + (model.chosen.count > 3 ? ", and more." : ".")) }
        return lines.joined(separator: " ")
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
                    Image(systemName: open ? "chevron.down" : "chevron.right").frame(width: 24, height: 24).contentShape(Rectangle())
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
                Button("Reveal in Finder") { StepActions.reveal(url) }
                Button("Never Touch This") { model.neverTouch(step) }
            }
            if step.facts.contains(where: { $0.label == "File" }) { Button("Open File") { StepActions.openFile(step) } }
            Button("Copy Command") { StepActions.copyCommand(step) }
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
    static func steps(_ n: Int) -> String { n == 1 ? "1 item" : "\(n) items" }
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

extension Action {
    /// True when the action ends with the item in the Trash, where you can put it back.
    var movesToTrash: Bool {
        switch self {
        case .trash, .adminTrash: true
        case .sequence(let parts): parts.contains { $0.movesToTrash }
        case .command, .none: false
        }
    }
}
