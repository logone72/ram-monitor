import Foundation

enum SnapshotBuilder {
  static func build(
    raw: RawMonitorSample,
    metric: MemoryMetric,
    topSliceCount: Int = 8
  ) -> MonitorSnapshot {
    let groups = makeGroups(from: raw.processes, metric: metric)
    let chart = makeChart(
      groups: groups,
      systemMemory: raw.systemMemory,
      metric: metric,
      topSliceCount: max(0, topSliceCount)
    )
    return MonitorSnapshot(metric: metric, groups: groups, chart: chart, sampledAt: raw.sampledAt)
  }

  private static func makeGroups(
    from processes: [ProcessSample],
    metric: MemoryMetric
  ) -> [ProcessGroup] {
    Dictionary(grouping: processes) { $0.bundle?.id ?? $0.path }
      .map { id, processes in
        let bundle = processes.compactMap(\.bundle).first
        return ProcessGroup(
          id: id,
          displayName: bundle?.displayName ?? processes.first?.name ?? id,
          bundlePath: bundle?.path,
          processes: processes,
          totalPhysicalFootprintBytes: sum(processes.compactMap(\.physicalFootprintBytes)),
          totalResidentSizeBytes: sum(processes.compactMap(\.residentSizeBytes)),
          totalCPUPercent: sum(processes.compactMap(\.cpuPercent)),
          totalThreads: sum(processes.compactMap(\.threadCount))
        )
      }
      .sorted { lhs, rhs in
        compareMemory(lhs.memoryBytes(for: metric), rhs.memoryBytes(for: metric))
      }
  }

  private static func makeChart(
    groups: [ProcessGroup],
    systemMemory: SystemMemorySample,
    metric: MemoryMetric,
    topSliceCount: Int
  ) -> MemoryChart {
    let measuredGroups = groups.compactMap { group -> (ProcessGroup, UInt64)? in
      group.memoryBytes(for: metric).map { (group, $0) }
    }
    let processSlices = makeProcessSlices(from: measuredGroups, topSliceCount: topSliceCount)

    switch metric {
    case .residentSize:
      return MemoryChart(
        denominatorBytes: sum(measuredGroups.map(\.1)) ?? 0,
        slices: processSlices,
        wasNormalized: false
      )
    case .physicalFootprint:
      let total = systemMemory.totalPhysicalBytes
      let systemUsed = cappedSum(
        [systemMemory.activeBytes, systemMemory.wiredBytes, systemMemory.compressedBytes],
        at: total
      )
      let available = total - systemUsed
      let measured = sum(measuredGroups.map(\.1)) ?? 0
      let wasNormalized = measured > systemUsed
      let visibleProcessSlices =
        wasNormalized
        ? scaled(processSlices, from: measured, to: systemUsed)
        : processSlices
      let visibleMeasured = wasNormalized ? systemUsed : measured
      var slices = visibleProcessSlices
      let unattributed = systemUsed - min(systemUsed, visibleMeasured)
      if unattributed > 0 {
        slices.append(
          ChartSlice(
            id: "unattributed",
            label: "System / Unattributed",
            bytes: unattributed,
            kind: .unattributed
          )
        )
      }
      if available > 0 {
        slices.append(
          ChartSlice(id: "available", label: "Available", bytes: available, kind: .available)
        )
      }
      return MemoryChart(
        denominatorBytes: total,
        slices: slices,
        wasNormalized: wasNormalized
      )
    }
  }

  private static func makeProcessSlices(
    from groups: [(ProcessGroup, UInt64)],
    topSliceCount: Int
  ) -> [ChartSlice] {
    var slices = groups.prefix(topSliceCount).map { group, bytes in
      ChartSlice(id: "group:\(group.id)", label: group.displayName, bytes: bytes, kind: .group)
    }
    let remainder = groups.dropFirst(min(topSliceCount, groups.count))
    if let otherBytes = sum(remainder.map(\.1)), !remainder.isEmpty {
      slices.append(ChartSlice(id: "other", label: "Other", bytes: otherBytes, kind: .other))
    }
    return slices
  }

  private static func scaled(
    _ slices: [ChartSlice],
    from sourceTotal: UInt64,
    to targetTotal: UInt64
  ) -> [ChartSlice] {
    guard sourceTotal > 0, !slices.isEmpty else { return slices }
    var remainingSource = sourceTotal
    var remainingTarget = targetTotal
    return slices.map { slice in
      let bytes: UInt64
      if slice.id == slices.last?.id {
        bytes = remainingTarget
      } else {
        let ratio = Double(slice.bytes) / Double(remainingSource)
        bytes = min(remainingTarget, UInt64((Double(remainingTarget) * ratio).rounded(.down)))
      }
      remainingSource -= slice.bytes
      remainingTarget -= bytes
      return ChartSlice(id: slice.id, label: slice.label, bytes: bytes, kind: slice.kind)
    }
  }

  private static func compareMemory(_ lhs: UInt64?, _ rhs: UInt64?) -> Bool {
    switch (lhs, rhs) {
    case (let lhs?, let rhs?): lhs == rhs ? false : lhs > rhs
    case (.some, nil): true
    default: false
    }
  }

  private static func sum(_ values: [UInt64]) -> UInt64? {
    guard !values.isEmpty else { return nil }
    var total: UInt64 = 0
    for value in values {
      let result = total.addingReportingOverflow(value)
      guard !result.overflow else { return nil }
      total = result.partialValue
    }
    return total
  }

  private static func sum(_ values: [Double]) -> Double? {
    guard !values.isEmpty else { return nil }
    let total = values.reduce(0, +)
    return total.isFinite ? total : nil
  }

  private static func sum(_ values: [Int32]) -> Int32? {
    guard !values.isEmpty else { return nil }
    var total: Int32 = 0
    for value in values {
      let result = total.addingReportingOverflow(value)
      guard !result.overflow else { return nil }
      total = result.partialValue
    }
    return total
  }

  private static func cappedSum(_ values: [UInt64], at cap: UInt64) -> UInt64 {
    values.reduce(0) { total, value in
      total >= cap || value >= cap - total ? cap : total + value
    }
  }
}
