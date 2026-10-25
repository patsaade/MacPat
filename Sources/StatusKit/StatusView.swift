// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Patrick Saade

import DesignSystem
import Foundation
import Observation
import SwiftUI

public struct StatusModule: MacPatModule {
    public let id = "status"
    public let title = "Status"
    public let symbol = "gauge.with.dots.needle.33percent"

    public init() {}

    public func makeView() -> AnyView { AnyView(StatusView()) }
}

/// Samples every two seconds while something on screen watches it, and stops when nothing does.
@MainActor @Observable
public final class StatusModel {
    public private(set) var snapshot = Snapshot()
    private let sampler = Sampler()
    private var task: Task<Void, Never>?

    private var fixed = false

    public init() {}

    /// Shows one reading and never samples. For demos.
    public init(fixed snapshot: Snapshot) {
        self.snapshot = snapshot
        fixed = true
    }

    public func start(every seconds: Double = 2) {
        guard task == nil, !fixed else { return }
        let sampler = sampler
        task = Task { [weak self] in
            while !Task.isCancelled {
                let s = await Task.detached { sampler.sample() }.value
                self?.snapshot = s
                try? await Task.sleep(for: .seconds(seconds))
            }
        }
    }

    public func stop() {
        task?.cancel()
        task = nil
    }
}

struct StatusView: View {
    @State var model = StatusModel()

    var body: some View {
        let s = model.snapshot
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Meter(title: "CPU", value: s.cpu, detail: "\(Int(s.cpu * 100))% busy across all cores")
                Meter(
                    title: "Memory", value: s.memoryTotal > 0 ? Double(s.memoryUsed) / Double(s.memoryTotal) : 0,
                    detail: "\(ByteFormat.string(s.memoryUsed)) of \(ByteFormat.string(s.memoryTotal)). Pressure: \(s.pressureWord).")
                Meter(
                    title: "Disk", value: s.diskTotal > 0 ? 1 - Double(s.diskFree) / Double(s.diskTotal) : 0,
                    detail: "\(ByteFormat.string(s.diskFree)) free of \(ByteFormat.string(s.diskTotal))")
                if let b = s.battery {
                    Meter(
                        title: "Battery", value: Double(b.percent) / 100,
                        detail: [
                            "\(b.percent)%", b.charging ? "charging" : nil, b.cycles.map { "\($0) cycles" },
                            b.health.map { "holds \($0)% of new" },
                        ]
                        .compactMap { $0 }.joined(separator: ", "))
                }
                Text("Heat: \(s.thermalWord)").bold()
                RetroRule(thickness: 1)
                HStack(alignment: .top, spacing: 24) {
                    ProcList(title: "Top CPU (your processes)", procs: s.topCPU) { "\(Int($0.cpu * 100))%" }
                    ProcList(title: "Top memory", procs: s.topMemory) { ByteFormat.string($0.memory) }
                }
                Text("Read locally from the kernel every two seconds while this screen is open. Nothing is stored or sent.")
                    .font(.caption.monospaced())
            }
            .padding(16)
        }
        .onAppear { model.start() }
        .onDisappear { model.stop() }
    }
}

struct Meter: View {
    let title: String
    let value: Double
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).bold()
                Spacer()
                Text("\(Int(value * 100))%").monospacedDigit()
            }
            Bar(fraction: value, line: 2).frame(height: 14)
            Text(detail).font(.callout.monospaced())
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(detail)
    }
}

struct ProcList: View {
    let title: String
    let procs: [Snapshot.Proc]
    let value: (Snapshot.Proc) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).bold()
            ForEach(procs) { p in
                HStack {
                    Text(p.name).lineLimit(1)
                    Spacer()
                    Text(value(p)).monospacedDigit()
                }
                .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// The compact readout inside the menu bar menu.
public struct StatusMenuLines: View {
    @State private var model = StatusModel()

    public init() {}

    public var body: some View {
        let s = model.snapshot
        VStack(alignment: .leading) {
            Text("CPU \(Int(s.cpu * 100))%")
            Text("Memory \(ByteFormat.string(s.memoryUsed)) used, pressure \(s.pressureWord)")
            Text("Disk \(ByteFormat.string(s.diskFree)) free")
        }
        .onAppear { model.start() }
        .onDisappear { model.stop() }
    }
}
