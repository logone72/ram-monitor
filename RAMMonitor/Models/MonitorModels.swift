import Foundation

enum MemoryMetric: String, CaseIterable, Hashable, Sendable {
  case physicalFootprint
  case residentSize
}

enum SortOrder: String, CaseIterable, Hashable, Sendable {
  case memory
  case cpu
  case name
  case processCount
}

struct BundleIdentity: Hashable, Sendable {
  let id: String
  let displayName: String
  let path: String
}

struct ProcessSample: Identifiable, Hashable, Sendable {
  struct Identity: Hashable, Sendable {
    let pid: pid_t
    let startTime: TimeInterval
  }

  let id: Identity
  let parentID: pid_t
  let name: String
  let path: String
  let bundle: BundleIdentity?
  let physicalFootprintBytes: UInt64?
  let residentSizeBytes: UInt64?
  let cpuPercent: Double?
  let threadCount: Int32?
  let architecture: String?

  func memoryBytes(for metric: MemoryMetric) -> UInt64? {
    switch metric {
    case .physicalFootprint: physicalFootprintBytes
    case .residentSize: residentSizeBytes
    }
  }
}

struct ProcessGroup: Identifiable, Sendable {
  let id: String
  let displayName: String
  let bundlePath: String?
  let processes: [ProcessSample]
  let totalPhysicalFootprintBytes: UInt64?
  let totalResidentSizeBytes: UInt64?
  let totalCPUPercent: Double?
  let totalThreads: Int32?

  func memoryBytes(for metric: MemoryMetric) -> UInt64? {
    switch metric {
    case .physicalFootprint: totalPhysicalFootprintBytes
    case .residentSize: totalResidentSizeBytes
    }
  }
}

struct ChartSlice: Identifiable, Sendable {
  enum Identity: Hashable, Sendable {
    case group(String)
    case other

    var accessibilityID: String {
      switch self {
      case .group(let groupID): "group:\(groupID)"
      case .other: "other"
      }
    }
  }

  let id: Identity
  let label: String
  let bytes: UInt64
}

struct MemoryChart: Sendable {
  let denominatorBytes: UInt64
  let slices: [ChartSlice]
}

struct SystemMemorySample: Sendable {
  let totalPhysicalBytes: UInt64
}

struct RawMonitorSample: Sendable {
  let processes: [ProcessSample]
  let systemMemory: SystemMemorySample
  let sampledAt: Date
}

struct MonitorSnapshot: Sendable {
  let metric: MemoryMetric
  let groups: [ProcessGroup]
  let chart: MemoryChart
  let totalPhysicalBytes: UInt64
  let sampledAt: Date
}

struct MonitorSettings: Sendable, Equatable {
  static let refreshIntervals: [TimeInterval] = [1, 2, 3, 5, 10]

  var memoryMetric: MemoryMetric = .physicalFootprint
  var refreshInterval: TimeInterval = 2
  var useBinaryUnits = false
  var defaultSortOrder: SortOrder = .memory
  var showThreadsColumn = true
  var showPIDColumn = false
  var showProcessCountColumn = false
  var showArchitectureColumn = false
}
