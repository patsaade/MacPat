// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Patrick Saade

import SwiftUI

/// One feature of the app. The sidebar lists every module the app registers.
@MainActor
public protocol MacPatModule {
    var id: String { get }
    var title: String { get }
    /// SF Symbol name.
    var symbol: String { get }
    func makeView() -> AnyView
}

public enum ByteFormat {
    public static func string(_ bytes: Int64) -> String {
        bytes.formatted(.byteCount(style: .file))
    }
}
