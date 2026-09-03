import Foundation
import Observation

typealias SampleProvider = @Sendable () async throws -> RawMonitorSample

@Observable
@MainActor
final class MonitorModel {
  var snapshot: MonitorSnapshot?
  var searchText = ""
  var sortOrder: SortOrder
  var sortAscending: Bool
  var expandedGroupIDs: Set<String> = []
  var lastRefreshError: String?
  private(set) var consecutiveRefreshFailures = 0
  private(set) var lastSuccessfulRefresh: Date?
  var settings: MonitorSettings {
    didSet {
      guard settings != oldValue else { return }
      saveSettings()
      if settings.defaultSortOrder != oldValue.defaultSortOrder {
        sortOrder = settings.defaultSortOrder
        sortAscending = sortOrder == .name
      }
      if settings.memoryMetric != oldValue.memoryMetric, let lastRawSample {
        snapshot = SnapshotBuilder.build(raw: lastRawSample, metric: settings.memoryMetric)
      }
    }
  }

  var visibleGroups: [ProcessGroup] {
    snapshot?.filtered(
      searchText: searchText,
      sortOrder: sortOrder,
      ascending: sortAscending
    ) ?? []
  }

  var isShowingStaleData: Bool {
    consecutiveRefreshFailures >= 2 && snapshot != nil
  }

  @ObservationIgnored private let defaults: UserDefaults
  @ObservationIgnored private let sampleProvider: SampleProvider
  @ObservationIgnored private var refreshTask: Task<Void, Never>?
  @ObservationIgnored private var lastRawSample: RawMonitorSample?

  convenience init(defaults: UserDefaults = .standard) {
    let sampler = ProcessSampler()
    self.init(defaults: defaults, sample: { try await sampler.sample() })
  }

  init(defaults: UserDefaults, sample: @escaping SampleProvider) {
    self.defaults = defaults
    self.sampleProvider = sample
    let settings = Self.loadSettings(from: defaults)
    self.settings = settings
    sortOrder = settings.defaultSortOrder
    sortAscending = settings.defaultSortOrder == .name
  }

  func start() {
    stop()
    refreshTask = Task { [weak self] in
      guard let self else { return }
      while !Task.isCancelled {
        await refresh()
        do {
          try await Task.sleep(for: .seconds(settings.refreshInterval))
        } catch {
          break
        }
      }
    }
  }

  func stop() {
    refreshTask?.cancel()
    refreshTask = nil
  }

  func refresh() async {
    do {
      let raw = try await sampleProvider()
      guard !Task.isCancelled else { return }
      lastRawSample = raw
      snapshot = SnapshotBuilder.build(raw: raw, metric: settings.memoryMetric)
      lastSuccessfulRefresh = raw.sampledAt
      lastRefreshError = nil
      consecutiveRefreshFailures = 0
    } catch is CancellationError {
      return
    } catch {
      lastRefreshError = "Unable to refresh processes"
      consecutiveRefreshFailures += 1
    }
  }

  func selectSortOrder(_ newOrder: SortOrder) {
    if sortOrder == newOrder {
      sortAscending.toggle()
    } else {
      sortOrder = newOrder
      sortAscending = newOrder == .name
    }
  }

  private func saveSettings() {
    defaults.set(settings.memoryMetric.rawValue, forKey: Keys.memoryMetric)
    defaults.set(settings.refreshInterval, forKey: Keys.refreshInterval)
    defaults.set(settings.useBinaryUnits, forKey: Keys.useBinaryUnits)
    defaults.set(settings.defaultSortOrder.rawValue, forKey: Keys.defaultSortOrder)
    defaults.set(settings.launchAtLogin, forKey: Keys.launchAtLogin)
    defaults.set(settings.showThreadsColumn, forKey: Keys.showThreadsColumn)
    defaults.set(settings.showPIDColumn, forKey: Keys.showPIDColumn)
    defaults.set(settings.showProcessCountColumn, forKey: Keys.showProcessCountColumn)
    defaults.set(settings.showArchitectureColumn, forKey: Keys.showArchitectureColumn)
  }

  private static func loadSettings(from defaults: UserDefaults) -> MonitorSettings {
    var settings = MonitorSettings()
    if let value = defaults.string(forKey: Keys.memoryMetric).flatMap(MemoryMetric.init) {
      settings.memoryMetric = value
    }
    let interval = defaults.double(forKey: Keys.refreshInterval)
    if [1, 2, 3, 5, 10].contains(interval) {
      settings.refreshInterval = interval
    }
    settings.useBinaryUnits = defaults.bool(forKey: Keys.useBinaryUnits)
    if let value = defaults.string(forKey: Keys.defaultSortOrder).flatMap(SortOrder.init) {
      settings.defaultSortOrder = value
    }
    settings.launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
    if defaults.object(forKey: Keys.showThreadsColumn) != nil {
      settings.showThreadsColumn = defaults.bool(forKey: Keys.showThreadsColumn)
    }
    settings.showPIDColumn = defaults.bool(forKey: Keys.showPIDColumn)
    settings.showProcessCountColumn = defaults.bool(forKey: Keys.showProcessCountColumn)
    settings.showArchitectureColumn = defaults.bool(forKey: Keys.showArchitectureColumn)
    return settings
  }

  private enum Keys {
    static let memoryMetric = "memoryMetric"
    static let refreshInterval = "refreshInterval"
    static let useBinaryUnits = "useBinaryUnits"
    static let defaultSortOrder = "defaultSortOrder"
    static let launchAtLogin = "launchAtLogin"
    static let showThreadsColumn = "showThreadsColumn"
    static let showPIDColumn = "showPIDColumn"
    static let showProcessCountColumn = "showProcessCountColumn"
    static let showArchitectureColumn = "showArchitectureColumn"
  }
}
