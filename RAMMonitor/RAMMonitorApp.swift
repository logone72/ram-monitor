import SwiftUI

@main
@MainActor
struct RAMMonitorApp: App {
  static let summaryContentHeight: CGFloat = 642
  static let defaultWindowHeight: CGFloat = 694
  @State private var model = makeModel()

  private static func makeModel() -> MonitorModel {
    #if DEBUG
      if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
        let suite = "com.roegankim.RAMMonitor.ui-testing"
        guard let defaults = UserDefaults(suiteName: suite) else {
          preconditionFailure("Unable to create isolated UI test preferences")
        }
        defaults.removePersistentDomain(forName: suite)
        return MonitorModel(defaults: defaults, sample: { UITestSample.raw })
      }
    #endif
    return MonitorModel()
  }

  var body: some Scene {
    Window("RAM Monitor", id: "main") {
      MonitorView(model: model)
        .frame(minWidth: 820, minHeight: 520)
    }
    .defaultSize(width: 1000, height: Self.defaultWindowHeight)

    Settings {
      SettingsView(model: model)
    }
  }
}
