import Darwin
import Foundation
import Testing

@testable import RAMMonitor

@Suite("ProcessSampler integration", .serialized)
struct ProcessSamplerIntegrationTests {
  @Test func sampleContainsCurrentProcessAndPhysicalRAM() async throws {
    let sampler = ProcessSampler()
    let raw = try await sampler.sample()
    let currentPID = ProcessInfo.processInfo.processIdentifier
    let current = try #require(raw.processes.first { $0.id.pid == currentPID })

    #expect(raw.systemMemory.totalPhysicalBytes == ProcessInfo.processInfo.physicalMemory)
    #expect(raw.systemMemory.totalPhysicalBytes > 0)
    #expect(current.physicalFootprintBytes != nil || current.residentSizeBytes != nil)
    #expect(current.bundle?.id == "com.roegankim.RAMMonitor")
  }

  @Test func firstCPUReadingIsUnavailable() async throws {
    let sampler = ProcessSampler()
    let raw = try await sampler.sample()
    #expect(raw.processes.allSatisfy { $0.cpuPercent == nil })
  }

  @Test func cpuUsesTheSameMachTickUnit() {
    let previous = CPUTimeSnapshot(user: 100, system: 100, timestamp: 1_000)
    let current = CPUTimeSnapshot(user: 400, system: 300, timestamp: 1_500)

    #expect(ProcessSampler.cpuPercent(previous: previous, current: current) == 100)
  }

  @Test func cpuRejectsCounterAndClockRollback() {
    let baseline = CPUTimeSnapshot(user: 100, system: 100, timestamp: 1_000)

    #expect(
      ProcessSampler.cpuPercent(
        previous: baseline,
        current: .init(user: 99, system: 100, timestamp: 1_500)
      ) == nil
    )
    #expect(
      ProcessSampler.cpuPercent(
        previous: baseline,
        current: .init(user: 200, system: 200, timestamp: 999)
      ) == nil
    )
  }

  @Test func cancelledSampleStopsBeforePublishing() async {
    let task = Task {
      withUnsafeCurrentTask { $0?.cancel() }
      return try await ProcessSampler().sample()
    }

    await #expect(throws: CancellationError.self) {
      _ = try await task.value
    }
  }

  @Test func secondCPUReadingIsFiniteAndArchitectureIsKnownWhenAvailable() async throws {
    let sampler = ProcessSampler()
    _ = try await sampler.sample()
    try await Task.sleep(for: .milliseconds(50))
    let raw = try await sampler.sample()
    let currentPID = ProcessInfo.processInfo.processIdentifier
    let current = try #require(raw.processes.first { $0.id.pid == currentPID })
    let cpu = try #require(current.cpuPercent)

    #expect(cpu.isFinite && cpu >= 0)
    #expect(current.architecture == nil || ["Apple", "Intel"].contains(current.architecture))
  }

  @Test func pidEnumerationUsesByteCapacityRetriesAndDropsInvalidEntries() throws {
    var fillCalls = 0
    var byteCounts: [Int32] = []
    let pids = try ProcessSampler.listAllPIDs { buffer, byteCount in
      guard let buffer else { return 1 }
      fillCalls += 1
      byteCounts.append(byteCount)
      let values = buffer.bindMemory(
        to: pid_t.self, capacity: Int(byteCount) / MemoryLayout<pid_t>.stride)
      if fillCalls == 1 { return 128 }
      values[0] = 42
      values[1] = 0
      values[2] = 42
      values[3] = 7
      return 4
    }

    #expect(
      byteCounts == [
        Int32(128 * MemoryLayout<pid_t>.stride),
        Int32(256 * MemoryLayout<pid_t>.stride),
      ])
    #expect(Set(pids) == [7, 42])
  }

  @Test func bundleResolutionUsesOutermostAppAndFiveParentLevels() throws {
    let bundleID = try #require(Bundle.main.bundleIdentifier)
    let appPath = Bundle.main.bundleURL.path
    let direct = BasicProcessInfo(
      pid: 1,
      parentID: 0,
      startTime: 1,
      name: "helper",
      path:
        "\(appPath)/Contents/Frameworks/Helper.app/Contents/XPCServices/Worker.xpc/Contents/MacOS/Worker"
    )
    var cache: [String: BundleIdentity] = [:]

    #expect(
      ProcessSampler.resolveBundle(for: direct, allProcesses: [1: direct], cache: &cache)?.id
        == bundleID
    )

    let child = BasicProcessInfo(
      pid: 10,
      parentID: 11,
      startTime: 1,
      name: "child",
      path: "/usr/bin/child"
    )
    var processes: [pid_t: BasicProcessInfo] = [10: child]
    for pid in 11...15 {
      processes[pid_t(pid)] = BasicProcessInfo(
        pid: pid_t(pid),
        parentID: pid == 15 ? pid_t(0) : pid_t(pid + 1),
        startTime: 1,
        name: "parent",
        path: pid == 15 ? "\(appPath)/Contents/MacOS/RAM Monitor" : "/usr/bin/parent-\(pid)"
      )
    }

    #expect(
      ProcessSampler.resolveBundle(for: child, allProcesses: processes, cache: &cache)?.id
        == bundleID
    )
  }

  @Test func repeatedSamplingDoesNotRetainStaleState() async throws {
    let sampler = ProcessSampler()
    var last = try await sampler.sample()
    for _ in 0..<4 {
      last = try await sampler.sample()
    }
    let retained = await sampler.retainedStateCounts()

    #expect(retained.cpu <= last.processes.count)
    #expect(retained.bundles <= Set(last.processes.map(\.path)).count)
    #expect(retained.processes <= last.processes.count)
  }
}
