// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Patrick Saade

import AppKit
import DesignSystem
import SwiftUI

struct RootView: View {
    @State private var selection: String? = modules.first?.id
    @State private var hasAccess = FullDiskAccess.granted

    private var current: (any MacPatModule)? { modules.first { $0.id == selection } }

    var body: some View {
        ZStack {
            RetroDesktop().ignoresSafeArea()
            VStack(spacing: 0) {
                menuBar
                RetroWindow(title: current?.title ?? "MacPat") {
                    VStack(spacing: 0) {
                        if !hasAccess {
                            accessBanner
                            RetroRule()
                        }
                        current?.makeView()
                    }
                }
                .padding(28)
            }
        }
        .font(Retro.font)
        .foregroundStyle(Retro.ink)
        .tint(Retro.ink)
        .buttonStyle(RetroButtonStyle())
        .toggleStyle(RetroToggleStyle())
        .frame(minWidth: 680, minHeight: 460)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            hasAccess = FullDiskAccess.granted
        }
    }

    private var menuBar: some View {
        HStack(spacing: 4) {
            PatMark().fill(Retro.ink).frame(width: 18, height: 18).padding(.trailing, 6).accessibilityHidden(true)
            Text("MacPat").bold().padding(.trailing, 12)
            ForEach(modules, id: \.id) { module in
                Button(module.title) { selection = module.id }
                    .buttonStyle(RetroTabStyle(selected: module.id == selection))
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .frame(height: 30)
        .background(Retro.paper)
        .overlay(alignment: .bottom) { RetroRule() }
    }

    private var accessBanner: some View {
        HStack {
            Image(systemName: "lock.shield").accessibilityHidden(true)
            Text("MacPat needs Full Disk Access to see every cache folder. It sends nothing anywhere.")
            Spacer()
            Button("Open Settings") { FullDiskAccess.openSettings() }
        }
        .padding(10)
        .accessibilityElement(children: .combine)
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
