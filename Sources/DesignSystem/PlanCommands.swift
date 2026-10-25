// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Patrick Saade

import SwiftUI

/// What the Plan menu can do to the screen in front: scan, preview, show commands, close the detail pane.
public struct PlanActions {
    public let scan: () -> Void
    public let preview: () -> Void
    public let toggleCommands: () -> Void
    public let closeDetail: () -> Void
    public let canScan: Bool
    public let canPreview: Bool
    public let detailOpen: Bool
}

private struct PlanActionsKey: FocusedValueKey {
    typealias Value = PlanActions
}

extension FocusedValues {
    public var planActions: PlanActions? {
        get { self[PlanActionsKey.self] }
        set { self[PlanActionsKey.self] = newValue }
    }
}
