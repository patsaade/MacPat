// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Patrick Saade

import Foundation

/// Maps in parallel and keeps the order. For blocking work such as walking folders or asking launchd,
/// where each item is independent. Each iteration writes its own slot, so nothing is shared.
public func concurrentMap<T: Sendable, U: Sendable>(_ items: [T], _ transform: @Sendable (T) -> U) -> [U] {
    guard items.count > 1 else { return items.map(transform) }
    var slots = [U?](repeating: nil, count: items.count)
    slots.withUnsafeMutableBufferPointer { buffer in
        let out = Slots(base: buffer.baseAddress!)
        DispatchQueue.concurrentPerform(iterations: items.count) { i in out.write(transform(items[i]), at: i) }
    }
    return slots.map { $0! }
}

private struct Slots<U>: @unchecked Sendable {
    let base: UnsafeMutablePointer<U?>
    func write(_ value: U, at index: Int) { base[index] = value }
}
