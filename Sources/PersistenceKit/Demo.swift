// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Patrick Saade

#if DEBUG
    import DesignSystem
    import Foundation
    import MacPatCore
    import SwiftUI

    @MainActor
    public enum PersistenceDemo {
        public static func steps() -> [Step] {
            let agents = LaunchItem.Place.userAgent.rawValue
            func agent(
                _ label: String, _ program: String, _ signed: String, _ risk: Risk, _ reason: String, unusual: String? = nil, loaded: Bool
            )
                -> Step
            {
                let plist = DemoKit.url("Library/LaunchAgents/\(label).plist")
                var facts = [Fact("Label", label), Fact("Program", program), Fact("Signed by", signed)]
                facts.append(Fact("State", loaded ? "loaded, enabled" : "not loaded, enabled"))
                if let unusual { facts.append(Fact("Unusual", unusual)) }
                var actions: [Action] = [.command(try! .disable(.gui(501), label: label))]
                if loaded { actions.append(.command(try! .bootout(.gui(501), label: label))) }
                return Step(
                    group: agents, title: label, risk: risk, reason: reason, facts: facts, action: .sequence(actions), id: plist.path)
            }
            return [
                agent(
                    "com.oldvpn.helper", "/Applications/OldVPN.app/Contents/MacOS/helper", "Program not found", .safe,
                    "Orphan. Its program is gone, so it only fails each time it starts.", loaded: false),
                agent(
                    "com.example.updater.agent", "/Users/pat/Library/Application Support/Example/Updater/updater",
                    "Developer ID (ABCDE12345)", .review,
                    "Stops Sketchpad from starting this every 3600 s. The app may lose a feature.",
                    loaded: true),
                agent(
                    "update.sync", "/bin/zsh", "Apple", .review,
                    "Unusual: runs a script through zsh, runs from a hidden folder. Not proof of harm. Find out what it is before you keep it.",
                    unusual: "runs a script through zsh; runs from a hidden folder", loaded: true),
                Step(
                    group: LaunchItem.Place.daemon.rawValue, title: "com.vendor.updaterd", risk: .review,
                    reason: "Stops Vendor Updater from starting this at login or boot. The app may lose a feature.",
                    facts: [
                        Fact("Program", "/Library/PrivilegedHelperTools/com.vendor.updaterd"),
                        Fact("Signed by", "Developer ID (ABCDE12345)"),
                    ],
                    action: .sequence([
                        .command(try! .disable(.system, label: "com.vendor.updaterd")),
                        .command(try! .bootout(.system, label: "com.vendor.updaterd")),
                    ]),
                    preselected: false),
                Step(
                    group: LaunchItem.Place.inApp.rawValue, title: "com.example.tunebox.helper", risk: .locked,
                    reason:
                        "Registered by its app through macOS. Turn it off in System Settings, General, Login Items & Extensions, or delete the app.",
                    action: .none, preselected: false, id: "inapp"),
            ]
        }

        public static func view(preview: Bool = true, commands: Bool = true) async -> AnyView {
            let model = await DemoKit.model(steps(), expanded: [LaunchItem.Place.userAgent.rawValue], preview: preview)
            model.showCommands = commands
            return AnyView(PersistenceView(demo: model))
        }
    }
#endif
