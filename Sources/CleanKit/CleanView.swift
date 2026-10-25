// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Patrick Saade

import DesignSystem
import MacPatCore
import SwiftUI

public struct CleanModule: MacPatModule {
    public let id = "clean"
    public let title = "Clean"
    public let symbol = "sparkles"

    public init() {}

    public func makeView() -> AnyView { AnyView(CleanView()) }
}

struct CleanView: View {
    @State private var model = CleanModel()
    @State private var confirming = false

    var body: some View {
        VStack(spacing: 0) {
            if let error = model.loadError {
                VStack(spacing: 8) {
                    Text("Rules failed to load").bold()
                    Text(error)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                list
                RetroRule()
                footer
            }
        }
        .task { await model.scan() }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(model.targets) { target in
                    row(target)
                    RetroRule(thickness: 1)
                }
            }
        }
        .overlay { if model.scanning { Text("Scanning…").padding(8).background(Retro.paper).border(Retro.ink, width: Retro.line) } }
    }

    private func row(_ target: Target) -> some View {
        let found = model.items[target.id] ?? []
        let bytes = found.reduce(Int64(0)) { $0 + $1.bytes }
        return Toggle(isOn: Binding(get: { model.selected.contains(target.id) }, set: { _ in model.toggle(target.id) })) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(target.name).bold()
                    Text(target.summary).font(.system(.callout, design: .monospaced))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(ByteFormat.string(bytes)).monospacedDigit()
                    Text("\(found.count) items, \(target.risk == .safe ? "safe" : "review first")")
                        .font(.system(.callout, design: .monospaced))
                }
            }
            .contentShape(Rectangle())
        }
        .disabled(found.isEmpty)
        .padding(12)
        .accessibilityElement(children: .combine)
    }

    private var footer: some View {
        HStack {
            Text(status)
            Spacer()
            Button("Scan") { Task { await model.scan() } }
                .disabled(model.scanning || model.working)
                .help("Look for files to clean. Nothing is changed.")
            Button("Preview") { Task { await model.run(dryRun: true) } }
                .disabled(model.chosenItems.isEmpty || model.working)
                .help("Shows what would be moved. Nothing is changed.")
            Button("Move to Trash…") { confirming = true }
                .disabled(!model.previewed || model.working)
                .help("Preview first. Then this unlocks.")
        }
        .padding(12)
        .confirmationDialog(
            "Move \(model.chosenItems.count) items to the Trash?", isPresented: $confirming, titleVisibility: .visible
        ) {
            Button("Move to Trash", role: .destructive) { Task { await model.run(dryRun: false) } }
        } message: {
            Text("\(ByteFormat.string(model.chosenBytes)) goes to the Trash. Empty the Trash to get the space back.")
        }
    }

    private var status: String {
        if let out = model.outcome {
            let verb = out.dryRun ? "Would move" : "Moved"
            let failed = out.failures.isEmpty ? "" : " \(out.failures.count) skipped."
            return "\(verb) \(out.count) items, \(ByteFormat.string(out.bytes)).\(failed)"
        }
        return model.chosenItems.isEmpty ? "Pick what to clean." : "\(ByteFormat.string(model.chosenBytes)) selected."
    }
}
