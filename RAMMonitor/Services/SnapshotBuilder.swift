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
      metric: metric,
      topSliceCount: max(0, topSliceCount)
    )
    return MonitorSnapshot(
      metric: metric, groups: groups, chart: chart,
      totalPhysicalBytes: raw.systemMemory.totalPhysicalBytes, sampledAt: raw.sampledAt
    )
  }

  private static func makeGroups(
    from processes: [ProcessSample],
    metric: MemoryMetric
  ) -> [ProcessGroup] {
    Dictionary(grouping: processes) { $0.bundle?.id ?? $0.path }
      .map { id, processes in
        let bundle = processes.compactMap(\.bundle).first
        let sortedProcesses = processes.sorted { lhs, rhs in
          optionalOrder(
            lhs.memoryBytes(for: metric),
            rhs.memoryBytes(for: metric),
            ascending: false
          ) ?? (lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending)
        }
        return ProcessGroup(
          id: id,
          displayName: bundle?.displayName
            ?? processes.first.map { ($0.path as NSString).lastPathComponent } ?? id,
          bundlePath: bundle?.path,
          processes: sortedProcesses,
          totalPhysicalFootprintBytes: sum(processes.compactMap(\.physicalFootprintBytes)),
          totalResidentSizeBytes: sum(processes.compactMap(\.residentSizeBytes)),
          totalCPUPercent: sum(processes.compactMap(\.cpuPercent)),
          totalThreads: sum(processes.compactMap(\.threadCount))
        )
      }
      .sorted { lhs, rhs in
        optionalOrder(
          lhs.memoryBytes(for: metric),
          rhs.memoryBytes(for: metric),
          ascending: false
        ) ?? (lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending)
      }
  }

  private static func makeChart(
    groups: [ProcessGroup],
    metric: MemoryMetric,
    topSliceCount: Int
  ) -> MemoryChart {
    let measuredGroups = groups.compactMap { group -> (ProcessGroup, UInt64)? in
      group.memoryBytes(for: metric).map { (group, $0) }
    }

    guard let measured = sum(measuredGroups.map(\.1)), measured > 0 else {
      return MemoryChart(denominatorBytes: 0, slices: [])
    }
    return MemoryChart(
      denominatorBytes: measured,
      slices: makeProcessSlices(from: measuredGroups, topSliceCount: topSliceCount)
    )
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

}

extension MonitorSnapshot {
  func filtered(
    searchText: String,
    sortOrder: SortOrder,
    ascending: Bool
  ) -> [ProcessGroup] {
    let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    let matches =
      query.isEmpty
      ? groups
      : groups.filter {
        $0.displayName.localizedCaseInsensitiveContains(query)
          || $0.processes.contains { $0.name.localizedCaseInsensitiveContains(query) }
      }
    return matches.sorted { lhs, rhs in
      let result: Bool?
      switch sortOrder {
      case .memory:
        result = optionalOrder(
          lhs.memoryBytes(for: metric),
          rhs.memoryBytes(for: metric),
          ascending: ascending
        )
      case .cpu:
        result = optionalOrder(lhs.totalCPUPercent, rhs.totalCPUPercent, ascending: ascending)
      case .name:
        let comparison = lhs.displayName.localizedStandardCompare(rhs.displayName)
        result =
          comparison == .orderedSame
          ? nil
          : ascending ? comparison == .orderedAscending : comparison == .orderedDescending
      case .processCount:
        result = optionalOrder(lhs.processes.count, rhs.processes.count, ascending: ascending)
      }
      return result
        ?? (lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending)
    }
  }
}

private func optionalOrder<Value: Comparable>(
  _ lhs: Value?,
  _ rhs: Value?,
  ascending: Bool
) -> Bool? {
  switch (lhs, rhs) {
  case (nil, nil): return nil
  case (nil, .some): return false
  case (.some, nil): return true
  case (let lhs?, let rhs?):
    guard lhs != rhs else { return nil }
    return ascending ? lhs < rhs : lhs > rhs
  }
}
