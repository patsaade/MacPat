// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Patrick Saade

import SwiftUI

/// Every duration and spring in the app. Reduce Motion is read here, once, so no view has to remember it.
/// Springs have no overshoot unless the user threw something; the scrollbar thumb is the one exception.
public enum Motion {
    /// Hover and press feedback.
    public static let quick = Animation.easeOut(duration: 0.12)
    /// Collapse, banners, fades.
    public static let settle = Animation.easeOut(duration: 0.22)
    /// Tabs, expand, the detail pane.
    public static let spring = Animation.spring(duration: 0.35, bounce: 0)
    /// A release after a drag.
    public static let release = Animation.spring(duration: 0.35, bounce: 0.25)
    /// One pat of the hand, in seconds.
    public static let pat: TimeInterval = 1.1
}

private struct MotionModifier<V: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduce
    let animation: Animation
    let value: V

    func body(content: Content) -> some View {
        content.animation(reduce ? nil : animation, value: value)
    }
}

extension View {
    /// Animates changes to `value`, unless Reduce Motion is on. Then the change is instant.
    public func motion<V: Equatable>(_ animation: Animation = Motion.spring, value: V) -> some View {
        modifier(MotionModifier(animation: animation, value: value))
    }

    /// Slides in from `edge`. Under Reduce Motion it fades instead.
    public func slides(from edge: Edge) -> some View { modifier(SlideModifier(edge: edge)) }
}

private struct SlideModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduce
    let edge: Edge

    func body(content: Content) -> some View {
        content.transition(reduce ? .opacity : .move(edge: edge).combined(with: .opacity))
    }
}
