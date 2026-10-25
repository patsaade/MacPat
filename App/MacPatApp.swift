// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Patrick Saade

import AnalyzeKit
import CleanKit
import DesignSystem
import OptimizeKit
import PersistenceKit
import StatusKit
import SwiftUI
import UninstallKit

/// Add a module here and it shows up in the menu bar.
@MainActor let modules: [any MacPatModule] = [
    CleanModule(), PersistenceModule(), UninstallModule(), AnalyzeModule(), StatusModule(), OptimizeModule(),
]

/// The Plan menu. It acts on whichever module is on screen.
struct PlanCommands: Commands {
    @FocusedValue(\.planActions) private var plan

    var body: some Commands {
        CommandMenu("Plan") {
            Button("Scan") { plan?.scan() }
                .keyboardShortcut("r", modifiers: .command).disabled(plan?.canScan != true)
            Button("Preview") { plan?.preview() }
                .keyboardShortcut("p", modifiers: [.command, .shift]).disabled(plan?.canPreview != true)
            Button("Show Commands") { plan?.toggleCommands() }
                .keyboardShortcut("k", modifiers: [.command, .shift]).disabled(plan == nil)
            Button("Close Detail") { plan?.closeDetail() }
                .disabled(plan?.detailOpen != true)
        }
    }
}

extension Notification.Name {
    static let selectModule = Notification.Name("io.github.patsaade.macpat.selectModule")
}

@main
struct MacPatApp: App {
    @Environment(\.openWindow) private var openWindow

    init() {
        #if DEBUG
            Demo.runIfAsked()
        #endif
    }

    var body: some Scene {
        Window("MacPat", id: "main") {
            #if DEBUG
                if Demo.live { LiveDemo() } else { RootView() }
            #else
                RootView()
            #endif
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1100, height: 720)
        .windowResizability(.contentMinSize)
        .windowBackgroundDragBehavior(.enabled)
        .commands {
            PlanCommands()
            CommandGroup(after: .sidebar) {
                ForEach(Array(modules.enumerated()), id: \.element.id) { index, module in
                    Button(module.title) {
                        NotificationCenter.default.post(name: .selectModule, object: module.id)
                    }
                    .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
                }
            }
        }
        Settings { SettingsView() }
        MenuBarExtra {
            StatusMenuLines()
            Divider()
            Button("Open MacPat") {
                openWindow(id: "main")
                NSApp.activate()
            }
            Divider()
            Button("Quit MacPat") { NSApplication.shared.terminate(nil) }.keyboardShortcut("q")
        } label: {
            Image(nsImage: PatMark.menuBar(lift: PatSignal.shared.lift)).accessibilityLabel("MacPat")
        }
    }
}
