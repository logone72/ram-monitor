import Foundation
import Testing

@testable import RAMMonitor

@Suite("MonitorModel")
struct MonitorModelTests {
  @Test @MainActor func refreshPublishesOneCoherentSnapshot() async throws {
    let raw = makeRawSample()
    let defaults = try #require(UserDefaults(suiteName: #function))
    defer { defaults.removePersistentDomain(forName: #function) }
    let model = MonitorModel(defaults: defaults, sample: { raw })

    model.settings.memoryMetric = .residentSize
    await model.refresh()

    let snapshot = try #require(model.snapshot)
    #expect(snapshot.metric == .residentSize)
    #expect(snapshot.chart.denominatorBytes == 200)
    #expect(model.visibleGroups.first?.memoryBytes(for: .residentSize) == 200)
  }

  @Test @MainActor func settingsUseDefaultsAndRoundTrip() throws {
    let suite = "MonitorModelTests.settings"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defaults.removePersistentDomain(forName: suite)
    defer { defaults.removePersistentDomain(forName: suite) }
    let model = MonitorModel(defaults: defaults, sample: { makeRawSample() })

    #expect(model.settings == MonitorSettings())
    #expect(model.sortOrder == .memory)
    #expect(!model.sortAscending)

    model.settings.memoryMetric = .residentSize
    model.settings.refreshInterval = 5
    model.settings.useBinaryUnits = true
    model.settings.defaultSortOrder = .name
    model.settings.launchAtLogin = true
    model.settings.showThreadsColumn = false
    model.settings.showPIDColumn = true
    model.settings.showProcessCountColumn = true
    model.settings.showArchitectureColumn = true

    let restored = MonitorModel(defaults: defaults, sample: { makeRawSample() })
    #expect(restored.settings == model.settings)
    #expect(restored.sortOrder == .name)
    #expect(restored.sortAscending)
  }

  @Test @MainActor func changingMetricRebuildsTheChartAndKeepsPhysicalRAMSeparate() async throws {
    let suite = "MonitorModelTests.metricChange"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defaults.removePersistentDomain(forName: suite)
    defer { defaults.removePersistentDomain(forName: suite) }
    let model = MonitorModel(defaults: defaults, sample: { makeRawSample() })
    await model.refresh()

    #expect(model.snapshot?.chart.denominatorBytes == 100)
    model.settings.memoryMetric = .residentSize
    #expect(model.snapshot?.chart.denominatorBytes == 200)
    #expect(model.snapshot?.chart.slices.first?.bytes == 200)
    #expect(model.visibleGroups.first?.memoryBytes(for: .residentSize) == 200)
    #expect(model.snapshot?.totalPhysicalBytes == 16_000)

    model.settings.memoryMetric = .physicalFootprint
    #expect(model.snapshot?.chart.denominatorBytes == 100)
    #expect(model.snapshot?.chart.slices.first?.bytes == 100)
    #expect(model.visibleGroups.first?.memoryBytes(for: .physicalFootprint) == 100)
    #expect(model.snapshot?.totalPhysicalBytes == 16_000)
  }

  @Test @MainActor func failedRefreshKeepsLastSnapshot() async throws {
    let suite = "MonitorModelTests.failure"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let provider = FailingSecondSample(raw: makeRawSample())
    let model = MonitorModel(defaults: defaults, sample: { try await provider.next() })

    await model.refresh()
    let firstDate = try #require(model.snapshot?.sampledAt)
    await model.refresh()
    await model.refresh()

    #expect(model.snapshot?.sampledAt == firstDate)
    #expect(model.lastRefreshError == "Unable to refresh processes")
    #expect(model.isShowingStaleData)
  }

  @Test @MainActor func failedLoginItemChangeKeepsStoredValue() throws {
    let suite = "MonitorModelTests.loginItem"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let model = MonitorModel(defaults: defaults, sample: { makeRawSample() })

    let error = SettingsView.applyLaunchAtLogin(true, to: model) { _ in
      throw TestError.failed
    }

    #expect(!model.settings.launchAtLogin)
    #expect(error != nil)

    let success = SettingsView.applyLaunchAtLogin(true, to: model) { _ in }
    #expect(model.settings.launchAtLogin)
    #expect(success == nil)
  }
}

private enum TestError: Error {
  case failed
}

private actor FailingSecondSample {
  let raw: RawMonitorSample
  var calls = 0

  init(raw: RawMonitorSample) {
    self.raw = raw
  }

  func next() throws -> RawMonitorSample {
    calls += 1
    guard calls == 1 else { throw TestError.failed }
    return raw
  }
}

private func makeRawSample() -> RawMonitorSample {
  RawMonitorSample(
    processes: [
      ProcessSample(
        id: .init(pid: 1, startTime: 1),
        parentID: 0,
        name: "editor",
        path: "/Applications/Editor.app/Contents/MacOS/Editor",
        bundle: .init(
          id: "com.example.editor",
          displayName: "Editor",
          path: "/Applications/Editor.app"
        ),
        physicalFootprintBytes: 100,
        residentSizeBytes: 200,
        cpuPercent: 3,
        threadCount: 4,
        architecture: "Apple"
      )
    ],
    systemMemory: .init(
      totalPhysicalBytes: 16_000,
      activeBytes: 8_000,
      wiredBytes: 2_000,
      compressedBytes: 1_000
    ),
    sampledAt: Date(timeIntervalSince1970: 10)
  )
}
