import SwiftUI

@main
@MainActor
struct RAMMonitorApp: App {
  static let summaryContentHeight: CGFloat = 642
  static let defaultWindowHeight: CGFloat = 694
  @State private var model = MonitorModel()

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
