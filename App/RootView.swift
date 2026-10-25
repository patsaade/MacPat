// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Patrick Saade

import AppKit
import DesignSystem
import SwiftUI

struct RootView: View {
    @State private var selection: String? = modules.first?.id
    @State private var hasAccess = FullDiskAccess.granted
    /// A fixed module and view for README snapshots. Nil in normal use.
    private var demo: (id: String, view: AnyView)?

    init() {}

    init(demo id: String, view: AnyView) {
        demo = (id, view)
        _selection = State(initialValue: id)
        _hasAccess = State(initialValue: true)
    }

    private var current: (any MacPatModule)? { modules.first { $0.id == selection } }

    var body: some View {
        ZStack {
            RetroDesktop().ignoresSafeArea()
            VStack(spacing: 0) {
                menuBar
                RetroWindow(title: current?.title ?? "MacPat") {
                    VStack(spacing: 0) {
                        if !hasAccess {
                            RetroBanner(.warning, "MacPat needs Full Disk Access to see every folder. It sends nothing anywhere.") {
                                Button("Open Settings") { FullDiskAccess.openSettings() }
                            }
                        }
                        (demo?.view ?? current?.makeView())
                            .id(selection)
                            .transition(.opacity)
                    }
                }
                .padding(28)
                .motion(Motion.settle, value: selection)
            }
        }
        .font(Retro.font)
        .foregroundStyle(Retro.ink)
        .tint(Retro.ink)
        .buttonStyle(RetroButtonStyle())
        .toggleStyle(RetroToggleStyle())
        .frame(minWidth: 860, minHeight: 560)
        .onReceive(NotificationCenter.default.publisher(for: .selectModule)) { note in
            if demo == nil, let id = note.object as? String { selection = id }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            if demo == nil { hasAccess = FullDiskAccess.granted }
        }
    }

    private var menuBar: some View {
        HStack(spacing: 4) {
            // The system title bar is hidden; leave room for the traffic lights.
            if demo == nil { Color.clear.frame(width: 70, height: 1) }
            PatMark().fill(Retro.ink).frame(width: 18, height: 18).padding(.trailing, 6).accessibilityHidden(true)
            Text("MacPat").bold().padding(.trailing, 12)
            ForEach(modules, id: \.id) { module in
                Button {
                    selection = module.id
                } label: {
                    Label(module.title, systemImage: module.symbol).labelStyle(.titleAndIcon)
                }
                .buttonStyle(RetroTabStyle(selected: module.id == selection))
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .frame(height: 38)
        .background(Retro.paper)
        .overlay(alignment: .bottom) { RetroRule() }
    }
}

enum FullDiskAccess {
    /// Safari's folder is protected. If we can list it, we have access.
    static var granted: Bool {
        (try? FileManager.default.contentsOfDirectory(atPath: NSHomeDirectory() + "/Library/Safari")) != nil
    }

    static func openSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }
}
