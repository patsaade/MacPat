// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Patrick Saade

import CleanKit
import DesignSystem
import SwiftUI

/// Add a module here and it shows up in the sidebar.
@MainActor let modules: [any MacPatModule] = [CleanModule()]

@main
struct MacPatApp: App {
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        Window("MacPat", id: "main") { RootView() }
        MenuBarExtra("MacPat", systemImage: "pawprint.fill") {
            Button("Open MacPat") { openWindow(id: "main") }
            Divider()
            Button("Quit MacPat") { NSApplication.shared.terminate(nil) }.keyboardShortcut("q")
        }
    }
}
