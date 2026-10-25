// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Patrick Saade

import SwiftUI

/// A notice strip across the top of a screen. Each kind has its own glyph and word,
/// so the meaning never rests on color. VoiceOver reads it out when it appears.
public struct RetroBanner<Actions: View>: View {
    public enum Kind: Sendable {
        case info, done, warning, admin, dryRun

        var symbol: String {
            switch self {
            case .info: "info.square"
            case .done: "checkmark.square"
            case .warning: "exclamationmark.triangle"
            case .admin: "lock.shield"
            case .dryRun: "eye"
            }
        }

        var word: String {
            switch self {
            case .info: "Note"
            case .done: "Done"
            case .warning: "Warning"
            case .admin: "Admin"
            case .dryRun: "Dry run"
            }
        }
    }

    let kind: Kind
    let text: String
    let actions: Actions

    public init(_ kind: Kind, _ text: String, @ViewBuilder actions: () -> Actions) {
        self.kind = kind
        self.text = text
        self.actions = actions()
    }

    public var body: some View {
        VStack(spacing: 0) {
            if kind == .dryRun {
                row
                    .background(Retro.paper)
                    .overlay(Rectangle().strokeBorder(Retro.ink, lineWidth: Retro.line))
                    .padding(8)
                    .background(Dither())
            } else {
                row.background(Retro.paper)
            }
            RetroRule(thickness: 1)
        }
        .accessibilityElement(children: .combine)
        .onChange(of: text, initial: true) { AccessibilityNotification.Announcement("\(kind.word). \(text)").post() }
    }

    /// Notes and results sit outlined. Warnings, admin, and dry run are inverted.
    private var plain: Bool { kind == .info || kind == .done }

    private var row: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: kind.symbol).accessibilityHidden(true)
            Text(kind.word.uppercased())
                .bold()
                .padding(.horizontal, 4)
                .foregroundStyle(plain ? Retro.ink : Retro.paper)
                .background(plain ? Retro.paper : Retro.ink)
            Text(text).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            actions
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

extension RetroBanner where Actions == EmptyView {
    public init(_ kind: Kind, _ text: String) { self.init(kind, text) { EmptyView() } }
}
