import SwiftUI

@main
struct RAMMonitorApp: App {
  var body: some Scene {
    Window("RAM Monitor", id: "main") {
      MonitorView()
    }
    .defaultSize(width: 1000, height: 680)

    Settings {
      Text("Settings")
        .padding()
    }
  }
}
