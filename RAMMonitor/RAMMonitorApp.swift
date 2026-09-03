import SwiftUI

@main
@MainActor
struct RAMMonitorApp: App {
  @State private var model = MonitorModel()

  var body: some Scene {
    Window("RAM Monitor", id: "main") {
      MonitorView(model: model)
        .frame(minWidth: 820, minHeight: 520)
    }
    .defaultSize(width: 1000, height: 680)

    Settings {
      Text("Settings")
        .padding()
    }
  }
}
