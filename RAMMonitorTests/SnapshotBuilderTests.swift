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

  @Test func groupsByBundleIDAndFallsBackToPath() {
    let sharedBundle = BundleIdentity(
      id: "com.example.browser",
      displayName: "Browser",
      path: "/Applications/Browser.app"
    )
    let raw = Fixtures.raw(processes: [
      .sample(
        id: 1,
        path: "/Applications/Browser.app/Contents/MacOS/Browser",
        bundle: sharedBundle
      ),
      .sample(
        id: 2,
        path: "/Applications/Browser.app/Contents/Frameworks/Helper",
        bundle: sharedBundle
      ),
      .sample(id: 3, path: "/usr/bin/task", bundle: nil),
    ])

    let result = SnapshotBuilder.build(raw: raw, metric: .physicalFootprint)

    #expect(result.groups.first { $0.id == "com.example.browser" }?.processes.count == 2)
    #expect(result.groups.first { $0.id == "/usr/bin/task" }?.displayName == "task")
  }

  @Test func keepsMatchingNamesSeparateWhenBundleIDsDiffer() {
    let bundles = ["com.a.browser", "com.b.browser"].map {
      BundleIdentity(id: $0, displayName: "Browser", path: "/Applications/Browser.app")
    }
    let result = SnapshotBuilder.build(
      raw: Fixtures.raw(processes: [
        .sample(id: 1, bundle: bundles[0]),
        .sample(id: 2, bundle: bundles[1]),
      ]),
      metric: .physicalFootprint
    )

    #expect(result.groups.count == 2)
  }

  @Test func filtersByGroupOrChildName() {
    let result = SnapshotBuilder.build(
      raw: Fixtures.raw(processes: [
        .sample(id: 1, group: "Editor", name: "language-server"),
        .sample(id: 2, group: "Browser", name: "renderer"),
      ]),
      metric: .physicalFootprint
    )

    #expect(
      result.filtered(searchText: "edit", sortOrder: .name, ascending: true).map(\.id)
        == ["Editor"]
    )
    #expect(
      result.filtered(searchText: "RENDER", sortOrder: .name, ascending: true).map(\.id)
        == ["Browser"]
    )
  }

  @Test func sortsAllSupportedColumns() {
    let alpha = BundleIdentity(id: "alpha", displayName: "Alpha 2", path: "/Alpha.app")
    let beta = BundleIdentity(id: "beta", displayName: "Alpha 10", path: "/Beta.app")
    let snapshot = SnapshotBuilder.build(
      raw: Fixtures.raw(processes: [
        .sample(id: 1, bundle: alpha, footprint: 100, cpu: 30),
        .sample(id: 2, bundle: beta, footprint: 300, cpu: 10),
        .sample(id: 3, bundle: beta, footprint: 200, cpu: 10),
      ]),
      metric: .physicalFootprint
    )

    #expect(
      snapshot.filtered(searchText: "", sortOrder: .memory, ascending: false).map(\.id)
        == ["beta", "alpha"]
    )
    #expect(
      snapshot.filtered(searchText: "", sortOrder: .cpu, ascending: false).map(\.id)
        == ["alpha", "beta"]
    )
    #expect(
      snapshot.filtered(searchText: "", sortOrder: .name, ascending: true).map(\.id)
        == ["alpha", "beta"]
    )
    #expect(
      snapshot.filtered(searchText: "", sortOrder: .processCount, ascending: false).map(\.id)
        == ["beta", "alpha"]
    )
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
    name: String? = nil,
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
      name: name ?? group ?? "process-\(id)",
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
