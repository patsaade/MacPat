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

@main
struct MacPatApp: App {
    @Environment(\.openWindow) private var openWindow

    init() {
        #if DEBUG
            Demo.runIfAsked()
        #endif
    }

    var body: some Scene {
        Window("MacPat", id: "main") { RootView() }
        MenuBarExtra {
            StatusMenuLines()
            Divider()
            Button("Open MacPat") { openWindow(id: "main") }
            Divider()
            Button("Quit MacPat") { NSApplication.shared.terminate(nil) }.keyboardShortcut("q")
        } label: {
            Image(nsImage: PatMark.menuBarImage).accessibilityLabel("MacPat")
        }
    }
}
