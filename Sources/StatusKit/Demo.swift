// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Patrick Saade

#if DEBUG
    import SwiftUI

    @MainActor
    public enum StatusDemo {
        public static func view() -> AnyView {
            var s = Snapshot()
            s.ready = true
            s.cpu = 0.23
            s.memoryUsed = 15_800_000_000
            s.memoryTotal = 24_000_000_000
            s.diskFree = 212_000_000_000
            s.diskTotal = 994_000_000_000
            s.battery = Battery(percent: 81, charging: false, cycles: 212, health: 94)
            s.topCPU = [("Xcode", 0.41), ("Sketchpad", 0.12), ("Tunebox", 0.04)].enumerated().map {
                Snapshot.Proc(pid: Int32($0.offset + 100), name: $0.element.0, cpu: $0.element.1, memory: 0)
            }
            s.topMemory = [("Xcode", 3_200_000_000), ("Sketchpad", 1_400_000_000), ("Chatterbox", 900_000_000)].enumerated().map {
                Snapshot.Proc(pid: Int32($0.offset + 200), name: $0.element.0, cpu: 0, memory: $0.element.1)
            }
            return AnyView(StatusView(model: StatusModel(fixed: s)))
        }
    }
#endif
