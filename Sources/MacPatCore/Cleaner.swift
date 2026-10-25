// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Patrick Saade

import Foundation

public struct Failure: Equatable, Sendable {
    public let url: URL
    public let reason: String
}

public struct Outcome: Equatable, Sendable {
    public let dryRun: Bool
    public var count = 0
    public var bytes: Int64 = 0
    public var failures: [Failure] = []
}

public struct Cleaner: Sendable {
    public typealias Dispose = @Sendable (URL) throws -> Void

    /// Moves to the Trash. MacPat has no permanent delete.
    public static let trash: Dispose = { try FileManager.default.trashItem(at: $0, resultingItemURL: nil) }

    public let zones: Zones

    public init(zones: Zones) { self.zones = zones }

    /// Every item is validated again right before it is touched. A dry run
    /// validates too, but disposes of nothing. Failures are listed, never fatal.
    // shortcut: a path can still change between validate and dispose; close it with
    // openat/fstatat on a held directory handle if this ever runs privileged.
    public func run(_ items: [Item], dryRun: Bool, dispose: Dispose = Cleaner.trash) -> Outcome {
        var outcome = Outcome(dryRun: dryRun)
        var done = Set<URL>()
        for item in items {
            do {
                let url = try zones.validate(item.url)
                guard done.insert(url).inserted else { continue }
                if !dryRun { try dispose(url) }
                outcome.count += 1
                outcome.bytes += item.bytes
            } catch {
                outcome.failures.append(Failure(url: item.url, reason: "\(error)"))
            }
        }
        return outcome
    }
}
