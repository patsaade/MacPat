// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Patrick Saade

import AppKit
import DesignSystem
import MacPatCore
import PersistenceKit
import SwiftUI

public struct UninstallModule: MacPatModule {
    public let id = "uninstall"
    public let title = "Uninstall"
    public let symbol = "trash.square"

    public init() {}

    public func makeView() -> AnyView { AnyView(UninstallView()) }
}

/// Builds the plan for one app, or for orphans when `app` is nil.
enum UninstallPlan {
    static func source(app: AppInfo?, home: URL) -> @Sendable () async -> [Step] {
        guard let app else {
            return {
                OrphanScanner(home: home) { id in
                    NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) != nil
                }.steps()
            }
        }
        return {
            var scanner = LeftoverScanner(app: app, home: home)
            scanner.running = await MainActor.run { Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier)) }
            scanner.launchItems = LaunchScanner.scan(home: home, includeApple: false, apps: [], runner: .live)
            scanner.receipts = receipts(for: app)
            return scanner.steps()
        }
    }

    static func receipts(for app: AppInfo) -> [String: Int] {
        guard let id = app.bundleID?.lowercased() else { return [:] }
        let pkgs = ((try? Runner.live.run(.pkgutilPackages())) ?? "").split(separator: "\n").map(String.init)
        var out: [String: Int] = [:]
        for pkg in pkgs where pkg.lowercased().hasPrefix(id) {
            let files = (try? Command.pkgutilFiles(pkg)).flatMap { try? Runner.live.run($0) } ?? ""
            out[pkg] = files.split(separator: "\n").count
        }
        return out
    }
}

struct UninstallView: View {
    @State private var apps: [AppInfo] = []
    @State private var selection: URL?
    @State private var orphans = false
    @State private var filter = ""
    @State private var model: PlanModel
    private let home = FileManager.default.homeDirectoryForCurrentUser

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        _model = State(
            initialValue: PlanModel(executor: Executor(zones: LeftoverScanner.zones(home: home), home: home, log: .standard(home: home))) {
                []
            })
    }

    init(demo apps: [AppInfo], selected: AppInfo, model: PlanModel) {
        _apps = State(initialValue: apps)
        _selection = State(initialValue: selected.url)
        _model = State(initialValue: model)
        demo = true
    }

    private var demo = false

    private var shown: [AppInfo] { filter.isEmpty ? apps : apps.filter { $0.name.localizedCaseInsensitiveContains(filter) } }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                TextField("Filter apps", text: $filter).textFieldStyle(.plain).padding(8).border(Retro.ink, width: 1).padding(8)
                RetroRule(thickness: 1)
                RetroScroll {
                    VStack(alignment: .leading, spacing: 0) {
                        row("Orphaned files", selected: orphans) { pick(nil) }
                        RetroRule(thickness: 1)
                        ForEach(shown) { app in
                            row(app.name + (app.isApple ? " (Apple)" : ""), selected: selection == app.url && !orphans) { pick(app) }
                        }
                    }
                }
            }
            .frame(width: 220)
            .dropDestination(for: URL.self) { urls, _ in
                guard let url = urls.first, url.pathExtension == "app" else { return false }
                pick(AppIndex.info(url))
                return true
            }
            Rectangle().fill(Retro.ink).frame(width: Retro.line).accessibilityHidden(true)
            if selection == nil && !orphans {
                Text("Pick an app on the left, or drop one here.").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                PlanView(model: model, empty: "Nothing found.") {
                    if let name = runningName {
                        RetroBanner(.warning, "Quit \(name) first. Everything stays locked while it runs. Then click Scan.")
                    }
                    if orphans {
                        RetroBanner(.warning, "Guesses. Each name looks like a bundle ID no installed app uses. Check before you remove.")
                    }
                }
            }
        }
        .task { if !demo { apps = await Task.detached { AppIndex.scan() }.value } }
    }

    private var runningName: String? {
        guard !orphans, let url = selection, let app = apps.first(where: { $0.url == url }), let id = app.bundleID else { return nil }
        return NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == id } ? app.name : nil
    }

    private func row(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 10).padding(.vertical, 4)
                .foregroundStyle(selected ? Retro.paper : Retro.ink)
                .background(selected ? Retro.ink : Retro.paper)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func pick(_ app: AppInfo?) {
        orphans = app == nil
        selection = app?.url
        model.setSource(UninstallPlan.source(app: app, home: home))
        Task { await model.scan() }
    }
}
