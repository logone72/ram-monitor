import AppKit
import SwiftUI
import Testing

@testable import RAMMonitor

@Suite("Memory layout")
struct MemoryLayoutTests {
  @Test(arguments: [CGFloat(600), CGFloat(694), CGFloat(1000)])
  @MainActor func initialWindowReservesSummarySpaceBelowToolbar(availableHeight: CGFloat) {
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 1000, height: 520),
      styleMask: [.titled, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
    window.toolbar = NSToolbar(identifier: "MemoryLayoutTests.toolbar")
    window.toolbarStyle = .unified
    let chromeHeight = window.frame.height - window.contentLayoutRect.height
    SummaryScrollConfiguration.fitInitialWindow(window, availableHeight: availableHeight)
    let expectedHeight = min(RAMMonitorApp.summaryContentHeight, availableHeight - chromeHeight)
    #expect(window.contentLayoutRect.height >= expectedHeight)
    #expect(window.frame.height <= availableHeight)

    let initialFrame = window.frame
    SummaryScrollConfiguration.fitInitialWindow(window, availableHeight: availableHeight)
    #expect(window.frame == initialFrame, "Repeated fitting must not keep growing the window")

  }

  @Test @MainActor func initialWindowPreservesLargerRestoredSize() {
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 1000, height: 900),
      styleMask: [.titled, .fullSizeContentView], backing: .buffered, defer: false)
    let initialFrame = window.frame
    SummaryScrollConfiguration.fitInitialWindow(window, availableHeight: 1000)
    #expect(window.frame == initialFrame)
  }

  @Test @MainActor func onlySummaryUsesOverlayScrollbars() throws {
    let suite = "MemoryLayoutTests.overlay"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let model = MonitorModel(defaults: defaults, sample: { throw CancellationError() })
    let root = NSHostingView(rootView: MonitorView(model: model))
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 1000, height: 694),
      styleMask: [], backing: .buffered, defer: false)
    defer {
      model.stop()
      window.contentView = nil
    }
    root.frame = window.frame
    root.layoutSubtreeIfNeeded()
    let scrolls = scrollViews(in: root).sorted {
      $0.convert($0.bounds, to: root).minX < $1.convert($1.bounds, to: root).minX
    }
    #expect(scrolls.count == 2)
    let summary = try #require(scrolls.first)
    let list = try #require(scrolls.last)
    summary.scrollerStyle = .legacy
    list.scrollerStyle = .legacy
    window.contentView = root
    root.layoutSubtreeIfNeeded()
    #expect(summary.scrollerStyle == .overlay)
    #expect(summary.autohidesScrollers)
    #expect(list.scrollerStyle == .legacy)
  }

  @Test @MainActor func fullSummaryFitsInitialViewport() {
    let chart = MemoryChart(
      denominatorBytes: 900,
      slices: (0..<9).map {
        ChartSlice(id: "group:\($0)", label: "Work unit \($0)", bytes: 100, kind: .group)
      })
    let view = NSHostingView(
      rootView: MemoryPieChart(
        chart: chart, metric: .physicalFootprint, totalPhysicalBytes: 16_000_000_000,
        useBinaryUnits: true, selectedGroupID: nil, selectedSliceID: nil,
        onSelectSlice: { _ in }
      ).frame(width: 360).fixedSize(horizontal: false, vertical: true))
    #expect(view.fittingSize.height <= RAMMonitorApp.summaryContentHeight)
  }

  @MainActor private func scrollViews(in view: NSView) -> [NSScrollView] {
    if let scroll = view as? NSScrollView { return [scroll] }
    return view.subviews.flatMap { scrollViews(in: $0) }
  }
}
