import Darwin
import Foundation
import Testing

@testable import RAMMonitor

@Suite("SnapshotBuilder")
struct SnapshotBuilderTests {
  @Test func physicalChartAlwaysMatchesPhysicalRAM() {
    let raw = Fixtures.raw(
      physicalRAM: 16_000,
      systemUsed: 12_000,
      processes: [
        .sample(id: 1, group: "browser", footprint: 5_000, resident: 7_000),
        .sample(id: 2, group: "editor", footprint: 3_000, resident: 4_000),
      ]
    )

    let result = SnapshotBuilder.build(raw: raw, metric: .physicalFootprint)

    #expect(result.chart.denominatorBytes == 16_000)
    #expect(result.chart.slices.reduce(0) { $0 + $1.bytes } == 16_000)
    #expect(result.chart.slices.contains { $0.kind == .available && $0.bytes == 4_000 })
  }

  @Test func residentChartUsesMeasuredProcessTotal() {
    let raw = Fixtures.rawWithTenGroups(residentBytesPerGroup: 100)
    let result = SnapshotBuilder.build(raw: raw, metric: .residentSize, topSliceCount: 8)

    #expect(result.chart.denominatorBytes == 1_000)
    #expect(result.chart.slices.filter { $0.kind == .group }.count == 8)
    #expect(result.chart.slices.first { $0.kind == .other }?.bytes == 200)
    #expect(!result.chart.slices.contains { $0.kind == .available })
    #expect(!result.chart.slices.contains { $0.kind == .unattributed })
  }
}

private enum Fixtures {
  static func raw(
    physicalRAM: UInt64 = 16_000,
    systemUsed: UInt64 = 12_000,
    processes: [ProcessSample]
  ) -> RawMonitorSample {
    RawMonitorSample(
      processes: processes,
      systemMemory: SystemMemorySample(
        totalPhysicalBytes: physicalRAM,
        activeBytes: systemUsed,
        wiredBytes: 0,
        compressedBytes: 0
      ),
      sampledAt: Date(timeIntervalSince1970: 1)
    )
  }

  static func rawWithTenGroups(residentBytesPerGroup: UInt64) -> RawMonitorSample {
    raw(
      processes: (1...10).map {
        .sample(id: pid_t($0), group: "group-\($0)", resident: residentBytesPerGroup)
      }
    )
  }
}

extension ProcessSample {
  fileprivate static func sample(
    id: pid_t,
    group: String? = nil,
    path: String? = nil,
    bundle: BundleIdentity? = nil,
    footprint: UInt64? = 100,
    resident: UInt64? = 100,
    cpu: Double? = 0
  ) -> ProcessSample {
    let resolvedBundle =
      bundle
      ?? group.map {
        BundleIdentity(id: $0, displayName: $0, path: "/Applications/\($0).app")
      }
    return ProcessSample(
      id: .init(pid: id, startTime: 1),
      parentID: 0,
      name: group ?? "process-\(id)",
      path: path ?? "/usr/bin/process-\(id)",
      bundle: resolvedBundle,
      physicalFootprintBytes: footprint,
      residentSizeBytes: resident,
      cpuPercent: cpu,
      threadCount: 1,
      architecture: "arm64"
    )
  }
}
