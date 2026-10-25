// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Patrick Saade

#if DEBUG
    import DesignSystem
    import Foundation
    import MacPatCore
    import SwiftUI

    @MainActor
    public enum AnalyzeDemo {
        public static func view() async -> AnyView {
            let gb: Int64 = 1_000_000_000
            let summary = VolumeSummary(
                total: 994 * gb, free: 212 * gb, important: 251 * gb, snapshots: ["2026-10-24-091500", "2026-10-23-091500"])
            let entries = [
                ("Library", 182 * gb, true), ("Movies", 96 * gb, true), ("Developer", 71 * gb, true), ("Downloads", 38 * gb, true),
                ("Pictures", 27 * gb, true), ("Documents", 12 * gb, true), ("Music", 4 * gb, true), ("notes.txt", 12_000, false),
            ].map { Entry(url: DemoKit.url($0.0), bytes: $0.1, isFolder: $0.2) }
            let model = await DemoKit.model([])
            return AnyView(AnalyzeView(demo: summary, entries: entries, model: model))
        }
    }
#endif
