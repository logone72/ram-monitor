import AppKit
import ServiceManagement
import SwiftUI

struct SettingsView: View {
  @Bindable var model: MonitorModel
  var readLoginItemStatus: () -> SMAppService.Status = { SMAppService.mainApp.status }
  @State private var launchAtLoginError: String?
  @State private var loginItemStatus = SMAppService.Status.notRegistered

  var body: some View {
    TabView {
      Form {
        Picker("RAM mode", selection: $model.settings.memoryMetric) {
          Text("Physical Footprint").tag(MemoryMetric.physicalFootprint)
          Text("Resident Size").tag(MemoryMetric.residentSize)
        }

        Picker("Refresh interval", selection: $model.settings.refreshInterval) {
          ForEach(MonitorSettings.refreshIntervals, id: \.self) { seconds in
            Text("\(seconds.formatted()) seconds").tag(seconds)
          }
        }

        Picker("Number format", selection: $model.settings.useBinaryUnits) {
          Text("Decimal").tag(false)
          Text("Binary").tag(true)
        }

        Picker("Default sort", selection: $model.settings.defaultSortOrder) {
          Text("RAM").tag(SortOrder.memory)
          Text("CPU").tag(SortOrder.cpu)
          Text("Name").tag(SortOrder.name)
        }

        Toggle("Launch at login", isOn: launchAtLoginBinding)

        if loginItemStatus == .requiresApproval {
          Text("Approval is required in System Settings before RAM Monitor can launch at login.")
            .font(.caption)
          Button("Open Login Items Settings") { SMAppService.openSystemSettingsLoginItems() }
          Button("Cancel pending registration") { setLaunchAtLogin(false) }
        } else if loginItemStatus == .notFound {
          Text("The login item is unavailable. Try again from an installed copy of RAM Monitor.")
            .font(.caption)
        }

        if let launchAtLoginError {
          Label(launchAtLoginError, systemImage: "exclamationmark.triangle.fill")
            .font(.caption)
            .foregroundStyle(.red)
        }
      }
      .formStyle(.grouped)
      .tabItem { Label("General", systemImage: "gearshape") }

      Form {
        Toggle("Threads", isOn: $model.settings.showThreadsColumn)
        Toggle("PID", isOn: $model.settings.showPIDColumn)
        Toggle("Processes", isOn: $model.settings.showProcessCountColumn)
        Toggle("Architecture", isOn: $model.settings.showArchitectureColumn)

        Text("RAM and CPU are always visible.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .formStyle(.grouped)
      .tabItem { Label("Columns", systemImage: "rectangle.split.3x1") }
    }
    .padding(12)
    .frame(width: 460, height: 370)
    .accessibilityIdentifier("settings-view")
    .onAppear { loginItemStatus = readLoginItemStatus() }
    .onReceive(
      NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification),
      perform: { _ in loginItemStatus = readLoginItemStatus() })
  }

  private var launchAtLoginBinding: Binding<Bool> {
    // Keep the closure: passing the method directly can crash Swift 6.3 IRGen.
    // https://github.com/swiftlang/swift/issues/82491
    Binding(
      get: { loginItemStatus == .enabled },
      set: { enabled in setLaunchAtLogin(enabled) }
    )
  }

  private func setLaunchAtLogin(_ enabled: Bool) {
    let result = Self.applyLaunchAtLogin(
      enabled,
      registration: { enabled in
        if enabled {
          try SMAppService.mainApp.register()
        } else {
          try SMAppService.mainApp.unregister()
        }
      },
      status: readLoginItemStatus)
    loginItemStatus = result.status
    launchAtLoginError = result.error
  }

  @MainActor
  static func applyLaunchAtLogin(
    _ enabled: Bool,
    registration: (Bool) throws -> Void,
    status: () -> SMAppService.Status
  ) -> (status: SMAppService.Status, error: String?) {
    do {
      if !enabled || status() != .requiresApproval { try registration(enabled) }
      return (status(), nil)
    } catch {
      return (status(), error.localizedDescription)
    }
  }
}
