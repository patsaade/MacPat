// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Patrick Saade

import Foundation
import Testing

@testable import StatusKit

@Suite struct SamplerTests {
    @Test func readingsAreInRange() throws {
        let sampler = Sampler()
        _ = sampler.sample()
        let s = sampler.sample()
        #expect((0...1).contains(s.cpu))
        #expect(s.memoryTotal > 0 && s.memoryUsed > 0 && s.memoryUsed <= s.memoryTotal)
        #expect(s.diskTotal > 0 && s.diskFree <= s.diskTotal)
        #expect(!s.topMemory.isEmpty && s.topMemory.allSatisfy { $0.memory >= 0 && !$0.name.isEmpty })
        if let b = s.battery { #expect((0...100).contains(b.percent)) }
    }
}
