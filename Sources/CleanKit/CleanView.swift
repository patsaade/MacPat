// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Patrick Saade

import AppKit
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

/// Builds Clean's plan model. Rules load once; picking a projects folder swaps the source.
@MainActor
public enum CleanSetup {
    public static func make(home: URL = FileManager.default.homeDirectoryForCurrentUser, projects: URL? = nil) -> Result<
        PlanModel, RuleError
    > {
        let zones = Zones(home: home)
        do {
            let targets = try RuleLoader.load(from: RuleLoader.bundledDirectory, home: home, zones: zones)
            let model = PlanModel(executor: executor(zones, home, projects)) { [] }
            model.setStreamingSource(stream(targets, zones, home, projects))
            model.remember(as: "clean")
            return .success(model)
        } catch let error as RuleError {
            return .failure(error)
        } catch {
            return .failure(.invalid(file: "Rules", reason: "\(error)"))
        }
    }

    static func executor(_ zones: Zones, _ home: URL, _ projects: URL?) -> Executor {
        let all = projects.map { zones.union(ProjectScanner(root: $0).zones) } ?? zones
        let system = Zones(roots: ["/Library/Caches", "/Library/Logs"].map { URL(filePath: $0) }, refusesApple: true)
        return Executor(zones: all, system: system, home: home, log: .standard(home: home))
    }

    static func stream(_ targets: [Target], _ zones: Zones, _ home: URL, _ projects: URL?)
        -> @Sendable (@escaping PlanModel.Batch) async
        -> Void
    {
        let source = CleanSource(targets: targets, zones: zones, home: home, projects: projects)
        return { batch in await source.stream(batch) }
    }

    static func source(_ targets: [Target], _ zones: Zones, _ home: URL, _ projects: URL?) -> @Sendable () async -> [Step] {
        let source = CleanSource(targets: targets, zones: zones, home: home, projects: projects)
        return { source.steps() }
    }
}

struct CleanView: View {
    @AppStorage("projectsFolder") private var projectsPath = ""
    @State private var setup = CleanSetup.make(projects: CleanView.savedProjects)
    @State private var badFolder = false

    init() {}

    init(demo model: PlanModel) {
        _setup = State(initialValue: .success(model))
        demo = true
    }

    private var demo = false

    static var savedProjects: URL? {
        UserDefaults.standard.string(forKey: "projectsFolder").flatMap { $0.isEmpty ? nil : URL(filePath: $0) }
    }

    var body: some View {
        switch setup {
        case .failure(let error):
            VStack(spacing: 0) {
                RetroBanner(.warning, "The Clean rules failed to load: \(String(describing: error))") {
                    Button("Retry") { setup = CleanSetup.make(projects: CleanView.savedProjects) }
                }
                Spacer()
            }
        case .success(let model):
            PlanView(
                model: model, layout: .grid,
                intro: Intro(
                    "clean", "Scan only reads. It looks for caches, logs, and build leftovers. Nothing changes until you Preview, then Run."
                ),
                empty: "Nothing to clean."
            ) { projectsBar(model) }
        }
    }

    private func projectsBar(_ model: PlanModel) -> some View {
        VStack(spacing: 0) {
            RetroToolbar {
                Text("Project build folders:").bold()
                Text(projectsPath.isEmpty || demo ? "off" : PathFormat.short(URL(filePath: projectsPath))).lineLimit(1).truncationMode(
                    .middle)
                Spacer()
                Button("Pick Folder…") { pick() }
                    .help("Look for node_modules, target, .build, and so forth inside one folder.")
                if !projectsPath.isEmpty { Button("Turn Off") { set(nil) } }
            }
            if badFolder {
                RetroBanner(.warning, "Pick a folder inside your home folder. Not home itself, and not a system folder.")
            }
        }
    }

    private func pick() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = "Use Folder"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        set(url)
    }

    private func set(_ url: URL?) {
        badFolder = url.map { ProjectScanner(root: $0).zones.roots.isEmpty } ?? false
        guard !badFolder else { return }
        projectsPath = url?.path ?? ""
        setup = CleanSetup.make(projects: url)
    }
}
