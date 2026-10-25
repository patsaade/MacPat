// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Patrick Saade

#if DEBUG
    import DesignSystem
    import Foundation
    import MacPatCore
    import SwiftUI

    @MainActor
    public enum UninstallDemo {
        public static func view(preview: Bool = true) async -> AnyView {
            let names = ["Chatterbox", "Dockyard", "Inkwell", "OldVPN", "Sketchpad", "Tunebox", "Wavelength"]
            let apps = names.map {
                AppInfo(url: URL(filePath: "/Applications/\($0).app"), name: $0, bundleID: nil, signature: Signature(kind: .developerID))
            }
            let app = apps[3]
            func s(_ group: String, _ rel: String, _ bytes: Int64, _ risk: Risk, _ reason: String, pre: Bool = true) -> Step {
                Step(
                    group: group, title: DemoKit.url(rel).lastPathComponent, bytes: bytes, risk: risk, reason: reason,
                    action: .trash(DemoKit.url(rel)), preselected: pre)
            }
            let id = "Named after the app's bundle ID, com.oldvpn.client."
            let steps = [
                s("App", "/Applications/OldVPN.app", 184_000_000, .safe, "The app itself."),
                s("Support files", "Library/Application Support/com.oldvpn.client", 52_000_000, .safe, id),
                s(
                    "Support files", "Library/Application Support/OldVPN", 3_100_000, .review,
                    "Matches the app's name only. Make sure it isn't another app's.", pre: false),
                s("Caches", "Library/Caches/com.oldvpn.client", 120_000_000, .safe, id),
                s("Preferences", "Library/Preferences/com.oldvpn.client.plist", 8_000, .safe, id),
                s(
                    "Shared containers", "Library/Group Containers/ABCDE12345.oldvpn", 9_400_000, .review,
                    "Shared by apps from the same developer (Team ID ABCDE12345). Their other apps may use it.", pre: false),
                Step(
                    group: "Starts at login", title: "com.oldvpn.helper", risk: .safe,
                    reason: "Runs a program inside OldVPN. It breaks once the app is gone.",
                    action: .sequence([.trash(DemoKit.url("Library/LaunchAgents/com.oldvpn.helper.plist"))])),
            ]
            let model = await DemoKit.model(
                steps,
                zones: [
                    "/Applications", "Library/Application Support", "Library/Caches", "Library/Preferences", "Library/Group Containers",
                    "Library/LaunchAgents",
                ],
                expanded: ["App", "Support files", "Shared containers"], preview: preview)
            return AnyView(UninstallView(demo: apps, selected: app, model: model))
        }
    }
#endif
