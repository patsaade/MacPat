// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Patrick Saade

import DesignSystem
import MacPatCore
import SwiftUI

/// Cmd-comma. Only what the app can actually change.
struct SettingsView: View {
    @State private var ignored = IgnoreList.load().paths
    @State private var access = FullDiskAccess.granted

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Full Disk Access").bold()
            Text(access ? "On. MacPat can see every folder it is allowed to scan." : "Off. Some folders will look empty.")
            Button("Open System Settings") { FullDiskAccess.openSettings() }
            RetroRule(thickness: 1)
            HStack {
                Text("Never touch").bold()
                Spacer()
                if !ignored.isEmpty {
                    Button("Remove All") {
                        var list = IgnoreList.load()
                        for path in list.paths { list.remove(path) }
                        list.save()
                        ignored = list.paths
                    }
                }
            }
            if ignored.isEmpty {
                Text("Nothing here. Right-click a step and choose Never Touch This to add one.")
            } else {
                RetroScroll {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(ignored, id: \.self) { path in
                            HStack {
                                Text(path).lineLimit(1).truncationMode(.middle)
                                Spacer()
                                Button("Remove") {
                                    var list = IgnoreList.load()
                                    list.remove(path)
                                    list.save()
                                    ignored = list.paths
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: 220)
            }
            RetroRule(thickness: 1)
            Text("MacPat sends nothing anywhere. It has no account and no updater.").font(.callout.monospaced())
        }
        .padding(20)
        .frame(width: 520, alignment: .leading)
        .frame(maxHeight: 520)
        .background(Retro.paper)
        .font(Retro.font)
        .foregroundStyle(Retro.ink)
        .buttonStyle(RetroButtonStyle())
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            access = FullDiskAccess.granted
            ignored = IgnoreList.load().paths
        }
    }
}
