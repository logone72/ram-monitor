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

  @Test func physicalChartNormalizesProcessSlicesWithoutChangingListValues() {
    let raw = Fixtures.raw(
      physicalRAM: 1_000,
      systemUsed: 600,
      processes: [
        .sample(id: 1, group: "browser", footprint: 500),
        .sample(id: 2, group: "editor", footprint: 400),
      ]
    )

    let result = SnapshotBuilder.build(raw: raw, metric: .physicalFootprint)

    #expect(result.chart.wasNormalized)
    #expect(result.groups.compactMap { $0.totalPhysicalFootprintBytes }.reduce(0, +) == 900)
    #expect(checkedSum(result.chart.slices.map(\.bytes)) == 1_000)
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

  @Test func groupAggregationSkipsMissingValuesAndRejectsOverflow() throws {
    let result = SnapshotBuilder.build(
      raw: Fixtures.raw(processes: [
        .sample(id: 1, group: "partial", footprint: nil),
        .sample(id: 2, group: "partial", footprint: 7),
        .sample(id: 3, group: "missing", footprint: nil),
        .sample(id: 4, group: "missing", footprint: nil),
        .sample(id: 5, group: "overflow", footprint: .max),
        .sample(id: 6, group: "overflow", footprint: 1),
      ]),
      metric: .physicalFootprint
    )

    #expect(
      try #require(result.groups.first { $0.id == "partial" }).totalPhysicalFootprintBytes == 7)
    #expect(
      try #require(result.groups.first { $0.id == "missing" }).totalPhysicalFootprintBytes == nil)
    #expect(
      try #require(result.groups.first { $0.id == "overflow" }).totalPhysicalFootprintBytes == nil)
  }

  @Test func chartAggregationOverflowCannotBreakItsDenominator() {
    let raw = Fixtures.raw(
      physicalRAM: 100,
      systemUsed: 80,
      processes: [
        .sample(id: 1, group: "a", footprint: .max, resident: .max),
        .sample(id: 2, group: "b", footprint: .max, resident: .max),
      ]
    )

    let physical = SnapshotBuilder.build(raw: raw, metric: .physicalFootprint)
    let resident = SnapshotBuilder.build(raw: raw, metric: .residentSize)

    #expect(checkedSum(physical.chart.slices.map(\.bytes)) == physical.chart.denominatorBytes)
    #expect(resident.chart.denominatorBytes == 0)
    #expect(resident.chart.slices.isEmpty)
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

  @Test func selectedMetricDrivesGroupsChartAndMemorySortTogether() {
    let raw = Fixtures.raw(processes: [
      .sample(id: 1, group: "footprint-heavy", footprint: 400, resident: 100),
      .sample(id: 2, group: "resident-heavy", footprint: 100, resident: 500),
    ])

    let physical = SnapshotBuilder.build(raw: raw, metric: .physicalFootprint)
    let resident = SnapshotBuilder.build(raw: raw, metric: .residentSize)

    #expect(
      physical.filtered(searchText: "", sortOrder: .memory, ascending: false).map(\.id)
        == ["footprint-heavy", "resident-heavy"]
    )
    #expect(physical.chart.slices.first { $0.kind == .group }?.id == "group:footprint-heavy")
    #expect(
      resident.filtered(searchText: "", sortOrder: .memory, ascending: false).map(\.id)
        == ["resident-heavy", "footprint-heavy"]
    )
    #expect(resident.chart.slices.first { $0.kind == .group }?.id == "group:resident-heavy")
  }
}

private func checkedSum(_ values: [UInt64]) -> UInt64? {
  var total: UInt64 = 0
  for value in values {
    let result = total.addingReportingOverflow(value)
    guard !result.overflow else { return nil }
    total = result.partialValue
  }
  return total
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
