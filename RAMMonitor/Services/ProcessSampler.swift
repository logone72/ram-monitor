import Darwin
import Foundation

enum SamplingError: Error, Sendable {
  case processEnumerationFailed(errno: Int32)
  case invalidPIDBufferSize
  case systemMemoryFailed(code: kern_return_t)
  case invalidSystemMemoryValue
}

struct CPUTimeSnapshot: Sendable {
  let user: UInt64
  let system: UInt64
  let timestamp: UInt64
}

struct BasicProcessInfo {
  let pid: pid_t
  let parentID: pid_t
  let startTime: TimeInterval
  let name: String
  let path: String
}

private struct StableProcessInfo {
  let name: String
  let path: String
  let architecture: String?
}

#if DEBUG
  struct RetainedStateCounts {
    let cpu: Int
    let bundles: Int
    let processes: Int
  }
#endif

actor ProcessSampler {
  private var previousCPU: [ProcessSample.Identity: CPUTimeSnapshot] = [:]
  private var bundleCache: [String: BundleIdentity] = [:]
  private var processInfoCache: [ProcessSample.Identity: StableProcessInfo] = [:]

  func sample() throws -> RawMonitorSample {
    try Task.checkCancellation()
    let sampledAt = Date()
    let timestamp = mach_absolute_time()
    let processPairs: [(pid_t, BasicProcessInfo)] = try Self.listAllPIDs().compactMap { pid in
      try Task.checkCancellation()
      return basicProcessInfo(pid: pid).map { (pid, $0) }
    }
    let processesByPID = Dictionary(uniqueKeysWithValues: processPairs)
    var nextCPU: [ProcessSample.Identity: CPUTimeSnapshot] = [:]
    var nextBundleCache = bundleCache
    var nextProcessInfoCache: [ProcessSample.Identity: StableProcessInfo] = [:]
    let processes: [ProcessSample] = try processesByPID.values.map { process in
      try Task.checkCancellation()
      let identity = ProcessSample.Identity(pid: process.pid, startTime: process.startTime)
      let architecture = cachedArchitecture(for: identity, pid: process.pid)
      let task = taskInfo(pid: process.pid)
      let currentCPU = task.map {
        CPUTimeSnapshot(user: $0.pti_total_user, system: $0.pti_total_system, timestamp: timestamp)
      }
      if let currentCPU {
        nextCPU[identity] = currentCPU
      }
      nextProcessInfoCache[identity] = StableProcessInfo(
        name: process.name,
        path: process.path,
        architecture: architecture
      )
      return ProcessSample(
        id: identity,
        parentID: process.parentID,
        name: process.name,
        path: process.path,
        bundle: Self.resolveBundle(
          for: process,
          allProcesses: processesByPID,
          cache: &nextBundleCache
        ),
        physicalFootprintBytes: physicalFootprint(pid: process.pid),
        residentSizeBytes: task?.pti_resident_size,
        cpuPercent: previousCPU[identity].flatMap { previous in
          currentCPU.flatMap { Self.cpuPercent(previous: previous, current: $0) }
        },
        threadCount: task.map { Int32($0.pti_threadnum) },
        architecture: architecture
      )
    }
    let systemMemory = try systemMemory()
    let currentPaths = Set(processes.map(\.path))
    nextBundleCache = nextBundleCache.filter { currentPaths.contains($0.key) }
    previousCPU = nextCPU
    bundleCache = nextBundleCache
    processInfoCache = nextProcessInfoCache
    return RawMonitorSample(
      processes: processes,
      systemMemory: systemMemory,
      sampledAt: sampledAt
    )
  }

  nonisolated static func cpuPercent(
    previous: CPUTimeSnapshot,
    current: CPUTimeSnapshot
  ) -> Double? {
    let (previousCPU, previousOverflow) = previous.user.addingReportingOverflow(previous.system)
    let (currentCPU, currentOverflow) = current.user.addingReportingOverflow(current.system)
    guard
      !previousOverflow, !currentOverflow, currentCPU >= previousCPU,
      current.timestamp > previous.timestamp
    else { return nil }

    return Double(currentCPU - previousCPU) / Double(current.timestamp - previous.timestamp) * 100
  }

  nonisolated static func listAllPIDs(
    using list: (UnsafeMutableRawPointer?, Int32) -> Int32 = proc_listallpids
  ) throws -> [pid_t] {
    let estimate = list(nil, 0)
    guard estimate > 0 else {
      throw SamplingError.processEnumerationFailed(errno: errno)
    }
    var capacity = max(Int(estimate) * 2, 128)

    for _ in 0..<3 {
      let (byteCount, overflow) = capacity.multipliedReportingOverflow(
        by: MemoryLayout<pid_t>.stride
      )
      guard !overflow, byteCount <= Int(Int32.max) else {
        throw SamplingError.invalidPIDBufferSize
      }
      var buffer = [pid_t](repeating: 0, count: capacity)
      let count = buffer.withUnsafeMutableBufferPointer {
        list($0.baseAddress, Int32(byteCount))
      }
      guard count > 0 else {
        throw SamplingError.processEnumerationFailed(errno: errno)
      }
      if Int(count) < capacity {
        return Array(Set(buffer.prefix(Int(count)).filter { $0 > 0 }))
      }
      let result = capacity.multipliedReportingOverflow(by: 2)
      guard !result.overflow else { throw SamplingError.invalidPIDBufferSize }
      capacity = result.partialValue
    }

    throw SamplingError.processEnumerationFailed(errno: EOVERFLOW)
  }

  private func basicProcessInfo(pid: pid_t) -> BasicProcessInfo? {
    var info = proc_bsdinfo()
    let size = Int32(MemoryLayout<proc_bsdinfo>.size)
    let result = withUnsafeMutablePointer(to: &info) {
      proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, $0, size)
    }
    guard result == size else { return nil }
    let seconds = info.pbi_start_tvsec
    let microseconds = info.pbi_start_tvusec
    let startTime = TimeInterval(seconds) + TimeInterval(microseconds) / 1_000_000
    let identity = ProcessSample.Identity(pid: pid, startTime: startTime)
    let stable = processInfoCache[identity]
    guard let path = stable?.path ?? processPath(pid: pid) else { return nil }
    return BasicProcessInfo(
      pid: pid,
      parentID: pid_t(info.pbi_ppid),
      startTime: startTime,
      name: stable?.name ?? (path as NSString).lastPathComponent,
      path: path
    )
  }

  private func processPath(pid: pid_t) -> String? {
    let capacity = Int(MAXPATHLEN) * 4
    var buffer = [CChar](repeating: 0, count: capacity)
    let length = buffer.withUnsafeMutableBufferPointer {
      proc_pidpath(pid, $0.baseAddress, UInt32($0.count))
    }
    guard length > 0, length < capacity else { return nil }
    return String(
      bytes: buffer.prefix(Int(length)).map { UInt8(bitPattern: $0) },
      encoding: .utf8
    )
  }

  private func taskInfo(pid: pid_t) -> proc_taskinfo? {
    var value = proc_taskinfo()
    let size = Int32(MemoryLayout<proc_taskinfo>.size)
    let result = withUnsafeMutablePointer(to: &value) {
      proc_pidinfo(pid, PROC_PIDTASKINFO, 0, $0, size)
    }
    return result == size ? value : nil
  }

  private func physicalFootprint(pid: pid_t) -> UInt64? {
    var value = rusage_info_v4()
    let result = withUnsafeMutablePointer(to: &value) { pointer in
      pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
        proc_pid_rusage(pid, RUSAGE_INFO_V4, $0)
      }
    }
    return result == 0 ? value.ri_phys_footprint : nil
  }

  private func architecture(pid: pid_t) -> String? {
    var value = proc_archinfo()
    let size = Int32(MemoryLayout<proc_archinfo>.size)
    let result = withUnsafeMutablePointer(to: &value) {
      proc_pidinfo(pid, PROC_PIDARCHINFO, 0, $0, size)
    }
    guard result == size else { return nil }
    switch value.p_cputype {
    case CPU_TYPE_ARM64: return "Apple"
    case CPU_TYPE_X86_64: return "Intel"
    default: return nil
    }
  }

  private func cachedArchitecture(for identity: ProcessSample.Identity, pid: pid_t) -> String? {
    if let stable = processInfoCache[identity] { return stable.architecture }
    return architecture(pid: pid)
  }

  private func systemMemory() throws -> SystemMemorySample {
    let total = ProcessInfo.processInfo.physicalMemory
    guard total > 0 else { throw SamplingError.invalidSystemMemoryValue }
    let host = mach_host_self()
    defer { mach_port_deallocate(mach_task_self_, host) }

    var pageSize: vm_size_t = 0
    let pageResult = host_page_size(host, &pageSize)
    guard pageResult == KERN_SUCCESS else {
      throw SamplingError.systemMemoryFailed(code: pageResult)
    }
    guard pageSize > 0 else { throw SamplingError.invalidSystemMemoryValue }

    var stats = vm_statistics64_data_t()
    var count = mach_msg_type_number_t(
      MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size
    )
    let statsResult = withUnsafeMutablePointer(to: &stats) { pointer in
      pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
        host_statistics64(host, HOST_VM_INFO64, $0, &count)
      }
    }
    guard statsResult == KERN_SUCCESS else {
      throw SamplingError.systemMemoryFailed(code: statsResult)
    }
    guard
      let active = checkedBytes(pages: stats.active_count, pageSize: pageSize),
      let wired = checkedBytes(pages: stats.wire_count, pageSize: pageSize),
      let compressed = checkedBytes(pages: stats.compressor_page_count, pageSize: pageSize)
    else { throw SamplingError.invalidSystemMemoryValue }

    return SystemMemorySample(
      totalPhysicalBytes: total,
      activeBytes: active,
      wiredBytes: wired,
      compressedBytes: compressed
    )
  }

  private func checkedBytes(pages: natural_t, pageSize: vm_size_t) -> UInt64? {
    let result = UInt64(pages).multipliedReportingOverflow(by: UInt64(pageSize))
    return result.overflow ? nil : result.partialValue
  }

  static func resolveBundle(
    for process: BasicProcessInfo,
    allProcesses: [pid_t: BasicProcessInfo],
    cache: inout [String: BundleIdentity]
  ) -> BundleIdentity? {
    if let cached = cache[process.path] { return cached }
    var appPath = outermostAppPath(in: process.path)
    var parentID = process.parentID
    var visited: Set<pid_t> = [process.pid]

    for _ in 0..<5 where appPath == nil {
      guard parentID > 0, visited.insert(parentID).inserted,
        let parent = allProcesses[parentID]
      else { break }
      appPath = outermostAppPath(in: parent.path)
      parentID = parent.parentID
    }
    guard let appPath, let bundle = Bundle(path: appPath),
      let id = bundle.bundleIdentifier
    else { return nil }
    let displayName =
      bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
      ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
      ?? ((appPath as NSString).lastPathComponent as NSString).deletingPathExtension
    let identity = BundleIdentity(id: id, displayName: displayName, path: appPath)
    cache[process.path] = identity
    return identity
  }

  private static func outermostAppPath(in path: String) -> String? {
    let components = (path as NSString).pathComponents
    guard let index = components.firstIndex(where: { $0.lowercased().hasSuffix(".app") }) else {
      return nil
    }
    return NSString.path(withComponents: Array(components[...index]))
  }

  #if DEBUG
    func retainedStateCounts() -> RetainedStateCounts {
      RetainedStateCounts(
        cpu: previousCPU.count,
        bundles: bundleCache.count,
        processes: processInfoCache.count
      )
    }
  #endif
}
