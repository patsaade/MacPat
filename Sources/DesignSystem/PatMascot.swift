// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Patrick Saade

import AppKit
import Observation
import SwiftUI

/// The hand and the Mac as a small living picture. It pats while a scan runs, once when a run is done,
/// and sits still in empty states. Under Reduce Motion it never moves.
public struct PatMascot: View {
    public enum Mode: Sendable { case idle, scanning, done }

    let mode: Mode
    @State private var start = Date()
    @State private var finished = false
    @Environment(\.accessibilityReduceMotion) private var reduce

    public init(_ mode: Mode) { self.mode = mode }

    public var body: some View {
        let still = reduce || mode == .idle || (mode == .done && finished)
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: still)) { context in
            PatPicture(lift: still ? 0 : lift(at: context.date.timeIntervalSince(start)))
        }
        .aspectRatio(1, contentMode: .fit)
        .clipped()
        .task(id: mode) {
            start = Date()
            finished = false
            guard mode == .done else { return }
            try? await Task.sleep(for: .seconds(1))
            finished = true
        }
        .accessibilityHidden(true)
    }

    /// Hand height above the screen after `t` seconds. Scanning loops. Done is one drop.
    private func lift(at t: TimeInterval) -> CGFloat {
        switch mode {
        case .idle: 0
        case .scanning: 4.5 * (1 + cos(2 * .pi * t / Motion.pat))
        case .done: 14 * pow(max(0, 1 - t / 0.3), 2)
        }
    }
}

/// Tells the menu bar mark to pat once, for example when a run finishes.
@MainActor @Observable
public final class PatSignal {
    public static let shared = PatSignal()
    public private(set) var lift: CGFloat = 0

    public func pat() async {
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
        for step in [10, 6, 2, 0] as [CGFloat] {
            lift = step
            try? await Task.sleep(for: .milliseconds(90))
        }
    }
}
