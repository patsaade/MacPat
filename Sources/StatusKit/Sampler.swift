// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Patrick Saade

import Darwin
import Foundation
import IOKit.ps

/// One reading of the machine. Everything comes from kernel and IOKit calls, no processes.
public struct Snapshot: Sendable, Equatable {
    public struct Proc: Sendable, Equatable, Identifiable {
        public let pid: Int32
        public let name: String
        public let cpu: Double
        public let memory: Int64
        public var id: Int32 { pid }
    }

    public var cpu: Double = 0
    public var memoryUsed: Int64 = 0
    public var memoryTotal: Int64 = 0
    /// 1 normal, 2 warning, 4 critical, as the kernel reports it.
    public var pressure: Int32 = 1
    public var diskFree: Int64 = 0
    public var diskTotal: Int64 = 0
    public var battery: Battery?
    public var thermal: ProcessInfo.ThermalState = .nominal
    public var topCPU: [Proc] = []
    public var topMemory: [Proc] = []

    public var pressureWord: String { pressure >= 4 ? "critical" : pressure >= 2 ? "warning" : "normal" }
    public var thermalWord: String {
        switch thermal {
        case .nominal: "normal"
        case .fair: "warm"
        case .serious: "hot, slowing down"
        case .critical: "critical"
        @unknown default: "unknown"
        }
    }
}

public struct Battery: Sendable, Equatable {
    public var percent: Int
    public var charging: Bool
    public var cycles: Int?
    /// Full charge now versus when new, as a percentage.
    public var health: Int?
}

/// Keeps the previous counters so CPU figures are deltas between two readings.
public final class Sampler: @unchecked Sendable {
    private var lastTicks: [UInt32]?
    private var lastProc: [Int32: UInt64] = [:]
    private var lastTime: UInt64 = 0
    private let lock = NSLock()

    public init() {}

    public func sample() -> Snapshot {
        lock.withLock {
            var s = Snapshot()
            s.cpu = cpu()
            (s.memoryUsed, s.memoryTotal) = memory()
            s.pressure = pressure()
            let disk = try? URL(filePath: "/").resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey])
            s.diskTotal = Int64(disk?.volumeTotalCapacity ?? 0)
            s.diskFree = Int64(disk?.volumeAvailableCapacity ?? 0)
            s.battery = battery()
            s.thermal = ProcessInfo.processInfo.thermalState
            let procs = processes()
            s.topCPU = Array(procs.sorted { $0.cpu > $1.cpu }.prefix(5))
            s.topMemory = Array(procs.sorted { $0.memory > $1.memory }.prefix(5))
            return s
        }
    }

    /// Busy share of all cores since the last call, 0 to 1.
    func cpu() -> Double {
        var count: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        guard host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &count, &info, &infoCount) == KERN_SUCCESS, let info
        else { return 0 }
        defer {
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), vm_size_t(infoCount) * vm_size_t(MemoryLayout<integer_t>.stride))
        }
        let ticks = (0..<Int(infoCount)).map { UInt32(bitPattern: info[$0]) }
        defer { lastTicks = ticks }
        guard let last = lastTicks, last.count == ticks.count else { return 0 }
        var busy: UInt64 = 0
        var total: UInt64 = 0
        let states = Int(CPU_STATE_MAX)
        for core in 0..<Int(count) {
            for state in 0..<states {
                let d = UInt64(ticks[core * states + state] &- last[core * states + state])
                total += d
                if state != Int(CPU_STATE_IDLE) { busy += d }
            }
        }
        return total > 0 ? Double(busy) / Double(total) : 0
    }

    /// App, wired, and compressed memory, the way macOS counts "Memory Used".
    func memory() -> (Int64, Int64) {
        var stats = vm_statistics64()
        var size = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)
        let ok = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) { host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &size) }
        }
        let total = Int64(ProcessInfo.processInfo.physicalMemory)
        guard ok == KERN_SUCCESS else { return (0, total) }
        let page = Int64(getpagesize())
        let app = Int64(stats.internal_page_count) - Int64(stats.purgeable_count)
        let used = (app + Int64(stats.wire_count) + Int64(stats.compressor_page_count)) * page
        return (max(0, used), total)
    }

    func pressure() -> Int32 {
        var level: Int32 = 1
        var size = MemoryLayout<Int32>.size
        sysctlbyname("kern.memorystatus_vm_pressure_level", &level, &size, nil, 0)
        return level
    }

    func battery() -> Battery? {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
            let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef],
            let first = list.first,
            let desc = IOPSGetPowerSourceDescription(blob, first)?.takeUnretainedValue() as? [String: Any],
            let current = desc[kIOPSCurrentCapacityKey] as? Int, let max = desc[kIOPSMaxCapacityKey] as? Int, max > 0
        else { return nil }
        var battery = Battery(percent: current * 100 / max, charging: desc[kIOPSIsChargingKey] as? Bool ?? false)
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        if service != 0 {
            defer { IOObjectRelease(service) }
            func value(_ key: String) -> Int? {
                IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Int
            }
            battery.cycles = value("CycleCount")
            if let full = value("AppleRawMaxCapacity"), let design = value("DesignCapacity"), design > 0 {
                battery.health = full * 100 / design
            }
        }
        return battery
    }

    /// The user's own processes. Others are off limits without root, and that's fine.
    func processes() -> [Snapshot.Proc] {
        var pids = [Int32](repeating: 0, count: 4096)
        let n = proc_listallpids(&pids, Int32(pids.count * MemoryLayout<Int32>.size))
        guard n > 0 else { return [] }
        var timebase = mach_timebase_info_data_t()
        mach_timebase_info(&timebase)
        let now = mach_absolute_time()
        let elapsed = Double(now &- lastTime) * Double(timebase.numer) / Double(timebase.denom)
        var next: [Int32: UInt64] = [:]
        var out: [Snapshot.Proc] = []
        for pid in pids.prefix(Int(n)) where pid > 0 {
            var usage = rusage_info_v4()
            let ok = withUnsafeMutablePointer(to: &usage) {
                $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { proc_pid_rusage(pid, RUSAGE_INFO_V4, $0) }
            }
            guard ok == 0 else { continue }
            let cpuTime = (usage.ri_user_time + usage.ri_system_time)
            next[pid] = cpuTime
            var name = [CChar](repeating: 0, count: 256)
            proc_name(pid, &name, UInt32(name.count))
            let ns = Double(cpuTime &- (lastProc[pid] ?? cpuTime)) * Double(timebase.numer) / Double(timebase.denom)
            let share = lastTime == 0 || elapsed <= 0 ? 0 : ns / elapsed
            out.append(
                Snapshot.Proc(
                    pid: pid, name: String(decoding: name.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self), cpu: share,
                    memory: Int64(usage.ri_phys_footprint)))
        }
        lastProc = next
        lastTime = now
        return out
    }
}
