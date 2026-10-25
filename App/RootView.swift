// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Patrick Saade

import AppKit
import DesignSystem
import SwiftUI

struct RootView: View {
    @State private var selection: String? = RootView.saved
    /// Modules opened so far. Each stays alive behind the one on screen, so its scan, its choices, and its
    /// sort are still there when you come back.
    @State private var opened: [String] = []
    @State private var hasAccess = FullDiskAccess.granted
    @AppStorage("fdaDismissed") private var fdaDismissed = false
    /// A fixed module and view for README snapshots. Nil in normal use.
    private var demo: (id: String, view: AnyView)?

    init() {}

    /// The module you were on last time, if it still exists.
    static var saved: String? {
        let id = UserDefaults.standard.string(forKey: "module")
        return modules.contains { $0.id == id } ? id : modules.first?.id
    }

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
                        if !hasAccess && !fdaDismissed {
                            RetroBanner(.warning, "MacPat needs Full Disk Access to see every folder. It sends nothing anywhere.") {
                                Button("Open Settings") { FullDiskAccess.openSettings() }
                                Button("Not Now") { fdaDismissed = true }
                            }
                        }
                        ZStack {
                            if let demo {
                                demo.view
                            } else {
                                ForEach(modules.filter { opened.contains($0.id) }, id: \.id) { module in
                                    let active = module.id == selection
                                    module.makeView()
                                        .opacity(active ? 1 : 0)
                                        .disabled(!active)
                                        .allowsHitTesting(active)
                                        .accessibilityHidden(!active)
                                        .environment(\.moduleActive, active)
                                }
                            }
                        }
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
        .onAppear { if let id = selection, !opened.contains(id) { opened.append(id) } }
        .onChange(of: selection) { _, id in
            guard demo == nil, let id else { return }
            if !opened.contains(id) { opened.append(id) }
            UserDefaults.standard.set(id, forKey: "module")
        }
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
