import AppKit
import SwiftUI

struct SummaryScrollConfiguration: NSViewRepresentable {
  func makeNSView(context: Context) -> ScrollViewProbe { ScrollViewProbe() }

  func updateNSView(_ view: ScrollViewProbe, context: Context) { view.applyStyle() }

  final class ScrollViewProbe: NSView {
    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      applyStyle()
      Task { @MainActor [weak self] in self?.fitInitialWindow() }
    }

    private func fitInitialWindow() {
      guard let window else { return }
      let chromeHeight = window.frame.height - window.contentLayoutRect.height
      let height = min(
        max(RAMMonitorApp.defaultWindowHeight, RAMMonitorApp.summaryContentHeight + chromeHeight),
        window.screen?.visibleFrame.height ?? RAMMonitorApp.defaultWindowHeight)
      var frame = window.frame
      guard frame.height < height else { return }
      frame.origin.y -= height - frame.height
      frame.size.height = height
      window.setFrame(frame, display: true)
    }

    func applyStyle() {
      enclosingScrollView?.scrollerStyle = .overlay
      enclosingScrollView?.autohidesScrollers = true
    }
  }
}
