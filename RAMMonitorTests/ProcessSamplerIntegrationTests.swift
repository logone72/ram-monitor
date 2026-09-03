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
}
