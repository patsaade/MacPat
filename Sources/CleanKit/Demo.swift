// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Patrick Saade

#if DEBUG
    import DesignSystem
    import Foundation
    import MacPatCore
    import SwiftUI

    @MainActor
    public enum CleanDemo {
        static let gb: Int64 = 1_000_000_000

        public static func steps() -> [Step] {
            func s(_ group: String, _ rel: String, _ bytes: Int64, _ risk: Risk, _ reason: String, _ back: String, _ modified: String)
                -> Step
            {
                Step(
                    group: group, title: DemoKit.url(rel).lastPathComponent, bytes: bytes, risk: risk, reason: reason,
                    facts: [Fact("Modified", modified), Fact("Comes back", back)], action: .trash(DemoKit.url(rel)))
            }
            let caches = "Caches and logs: App caches"
            let cachesWhy = "Apps keep these to start faster. They rebuild them on demand."
            let rebuild = "Apps rebuild them as they run. First launch may be slower."
            return [
                s(caches, "Library/Caches/com.example.tunebox", 2 * gb + 310_000_000, .safe, cachesWhy, rebuild, "2 hours ago"),
                s(caches, "Library/Caches/com.example.chatterbox", 870_000_000, .safe, cachesWhy, rebuild, "yesterday"),
                s(caches, "Library/Caches/com.example.sketchpad", 412_000_000, .safe, cachesWhy, rebuild, "3 days ago"),
                s(
                    "Caches and logs: Logs", "Library/Logs/com.example.wavelength", 96_000_000, .safe,
                    "Text logs apps write as they run. Nothing reads them back.",
                    "Apps start new logs.", "last week"),
                s(
                    "Developer: Xcode build files", "Library/Developer/Xcode/DerivedData/MacPat-abcdef", 6 * gb + 200_000_000, .safe,
                    "Indexes and build products for each project.", "The next build is a full build.", "4 days ago"),
                s(
                    "Developer: Device support files", "Library/Developer/Xcode/iOS DeviceSupport/iPhone17,1 18.2", 4 * gb, .safe,
                    "One folder per device OS version. Old versions are dead weight.", "Copied again the next time that device connects.",
                    "8 months ago"),
                s(
                    "Package caches: Homebrew downloads", "Library/Caches/Homebrew/downloads", 1 * gb + 700_000_000, .safe,
                    "Kept so a reinstall skips the download.", "Downloaded again if you reinstall.", "2 weeks ago"),
                s(
                    "Mail and downloads: Old installers", "Downloads/Dockyard-4.2.dmg", 1 * gb + 900_000_000, .review,
                    "Usually installed already. Check the source before you let one go.", "Download it again from where it came from.",
                    "3 months ago"),
                s(
                    "Backups: iPhone and iPad backups", "Library/Application Support/MobileSync/Backup/00008110-0012", 38 * gb, .review,
                    "This may be your only backup of that device. Check the name and date.",
                    "Can't be rebuilt. Only a new backup replaces it.",
                    "last year"),
            ]
        }

        public static func view(
            expanded: [String] = ["Caches and logs: App caches"], preview: Bool = true, commands: Bool = false, pane: Bool = false
        ) async
            -> AnyView
        {
            let model = await DemoKit.model(
                steps(),
                zones: ["Library/Caches", "Library/Logs", "Library/Developer", "Downloads", "Library/Application Support/MobileSync"],
                expanded: expanded, preview: preview)
            model.showCommands = commands
            if pane, let step = model.visibleSteps.dropFirst().first {
                model.select(step, openPane: true)
            }
            return AnyView(CleanView(demo: model))
        }
    }
#endif
