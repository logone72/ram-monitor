import ServiceManagement
import SwiftUI

struct SettingsView: View {
  @Bindable var model: MonitorModel
  @State private var launchAtLoginError: String?

  var body: some View {
    TabView {
      Form {
        Picker("RAM mode", selection: $model.settings.memoryMetric) {
          Text("Physical Footprint").tag(MemoryMetric.physicalFootprint)
          Text("Resident Size").tag(MemoryMetric.residentSize)
        }

        Picker("Refresh interval", selection: $model.settings.refreshInterval) {
          ForEach([1.0, 2.0, 3.0, 5.0, 10.0], id: \.self) { seconds in
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
  }

  private var launchAtLoginBinding: Binding<Bool> {
    Binding(
      get: { model.settings.launchAtLogin },
      set: { enabled in
        launchAtLoginError = Self.applyLaunchAtLogin(enabled, to: model) { enabled in
          if enabled {
            try SMAppService.mainApp.register()
          } else {
            try SMAppService.mainApp.unregister()
          }
        }
      }
    )
  }

  @MainActor
  static func applyLaunchAtLogin(
    _ enabled: Bool,
    to model: MonitorModel,
    registration: (Bool) throws -> Void
  ) -> String? {
    do {
      try registration(enabled)
      model.settings.launchAtLogin = enabled
      return nil
    } catch {
      return error.localizedDescription
    }
  }
}
