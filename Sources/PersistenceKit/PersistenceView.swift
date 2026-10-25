// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Patrick Saade

import DesignSystem
import MacPatCore
import SwiftUI

public struct PersistenceModule: MacPatModule {
    public let id = "persistence"
    public let title = "Startup Items"
    public let symbol = "arrow.triangle.2.circlepath"

    public init() {}

    public func makeView() -> AnyView { AnyView(PersistenceView()) }
}

struct PersistenceView: View {
    @State private var source = PersistenceSource(mode: .disable, home: FileManager.default.homeDirectoryForCurrentUser)
    @State private var model: PlanModel
    @State private var deepError: String?
    @State private var explainDeep = false

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let initial = PersistenceSource(mode: .disable, home: home)
        _source = State(initialValue: initial)
        _model = State(
            initialValue: PlanModel(
                executor: Executor(zones: PersistenceSource.zones(home: home), home: home, log: .standard(home: home))
            ) { initial.steps() }.remembering("persistence"))
    }

    init(demo model: PlanModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        PlanView(
            model: model, layout: .grid,
            intro: Intro(
                "startup", "Everything that starts on its own, from launch agents to shell lines. Scan only reads. Disable keeps the file."),
            runLabel: "\(source.mode.rawValue)…", empty: "Nothing found that starts on its own."
        ) {
            VStack(spacing: 0) {
                RetroBanner(.info, "This is not a malware scan. Unusual means worth a look, not harmful.")
                RetroToolbar {
                    RetroSegments(
                        "Action", options: PersistenceMode.allCases.map { ($0, $0.rawValue) },
                        selection: Binding(get: { source.mode }, set: { update { $0.mode = $1 }($0) })
                    )
                    .help(source.mode.help)
                    Toggle("Show Apple items", isOn: Binding(get: { source.includeApple }, set: { update { $0.includeApple = $1 }($0) }))
                    Spacer()
                    Button("Deep Scan…") { explainDeep = true }
                        .help("Reads the full Login Items list with sfltool. macOS asks for your password. Read-only.")
                }
                Text(source.mode.help).font(.callout.monospaced()).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 12)
                    .padding(.vertical, 6)
                RetroRule(thickness: 1)
                if let deepError { RetroBanner(.warning, "Deep scan failed: \(deepError)") }
            }
        }
        .confirmationDialog("Run a deep scan?", isPresented: $explainDeep, titleVisibility: .visible) {
            Button("Continue") { Task { await deepScan() } }
        } message: {
            Text("This reads the full Login Items list with sfltool. macOS will ask for your password. It only reads. Nothing is changed.")
        }
    }

    private func update<V>(_ change: @escaping (inout PersistenceSource, V) -> Void) -> (V) -> Void {
        { value in
            change(&source, value)
            let next = source
            model.setSource { next.steps() }
            Task { await model.scan() }
        }
    }

    private func deepScan() async {
        let result = await Task.detached { Result { try Runner.live.run(.backgroundItems()) } }.value
        switch result {
        case .success(let text):
            deepError = nil
            update { (s: inout PersistenceSource, t: String?) in s.deepScan = t }(text)
        case .failure(let error):
            deepError = "\(error)"
        }
    }
}
