import XCTest

final class RAMMonitorUITests: XCTestCase {
  @MainActor
  func testRepeatedSelectionClearsHighlight() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-refreshInterval", "10", "-defaultSortOrder", "memory"]
    app.launch()
    let legend = app.buttons.matching(
      NSPredicate(format: "identifier BEGINSWITH 'chart-legend:group:'")
    ).firstMatch
    XCTAssertTrue(legend.waitForExistence(timeout: 5))
    let center = app.descendants(matching: .any)["chart-center"]
    legend.click()
    XCTAssertTrue(legend.isSelected)
    legend.click()
    XCTAssertFalse(legend.isSelected)
    XCTAssertEqual(center.label, "Measured process total", "Hover must not undo deselection")

    let groupID = String(legend.identifier.dropFirst("chart-legend:group:".count))
    let row = app.descendants(matching: .any)["work-unit:\(groupID)"]
    row.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.5)).click()
    XCTAssertTrue(legend.isSelected)
    row.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.5)).click()
    XCTAssertFalse(legend.isSelected)
    XCTAssertEqual(center.label, "Measured process total")

    let chart = app.descendants(matching: .any)["memory-pie-chart"]
    let slice = chart.coordinate(withNormalizedOffset: CGVector(dx: 0.505, dy: 0.1))
    slice.click()
    XCTAssertTrue(legend.isSelected)
    slice.click()
    XCTAssertFalse(legend.isSelected)
    XCTAssertEqual(center.label, "Measured process total")
    app.buttons["Sort by RAM"].hover()
    legend.hover()
    XCTAssertEqual(center.label, legend.label, "Hover must resume after leaving the cleared item")
    XCTAssertFalse(legend.isSelected, "Hover must not select a row")
  }

  @MainActor
  func testNonSelectionClicksClearHighlight() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-refreshInterval", "10", "-defaultSortOrder", "memory"]
    app.launch()
    let legend = app.buttons.matching(
      NSPredicate(format: "identifier BEGINSWITH 'chart-legend:group:'")
    ).firstMatch
    XCTAssertTrue(legend.waitForExistence(timeout: 5))
    let center = app.descendants(matching: .any)["chart-center"]
    legend.click()
    let chart = app.descendants(matching: .any)["memory-pie-chart"]
    chart.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
    XCTAssertFalse(legend.isSelected)
    XCTAssertEqual(center.label, "Measured process total")

    legend.click()
    app.staticTexts["Physical Footprint"].click()
    XCTAssertFalse(legend.isSelected)
    XCTAssertEqual(center.label, "Measured process total")

    legend.click()
    app.buttons["Sort by RAM"].click()
    XCTAssertFalse(legend.isSelected)
    XCTAssertEqual(center.label, "Measured process total")

    legend.click()
    let other = app.descendants(matching: .any)["chart-legend:other"]
    other.click()
    XCTAssertFalse(legend.isSelected)
    XCTAssertEqual(center.label, "Measured process total")
    app.buttons["Sort by RAM"].hover()
    other.hover()
    XCTAssertEqual(center.label, "Other")
    other.click()
    XCTAssertEqual(center.label, "Measured process total", "Other hover alone must also clear")

    legend.click()
    app.searchFields["Search work units"].click()
    XCTAssertFalse(legend.isSelected)
    XCTAssertEqual(center.label, "Measured process total")
  }

  @MainActor
  func testBlankListAndDisclosureClearSelection() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-refreshInterval", "10", "-defaultSortOrder", "memory"]
    app.launch()
    let legend = app.buttons.matching(
      NSPredicate(format: "identifier BEGINSWITH 'chart-legend:group:'")
    ).firstMatch
    XCTAssertTrue(legend.waitForExistence(timeout: 5))
    let groupID = String(legend.identifier.dropFirst("chart-legend:group:".count))
    let row = app.descendants(matching: .any)["work-unit:\(groupID)"]
    let center = app.descendants(matching: .any)["chart-center"]
    let search = app.searchFields["Search work units"]
    search.click()
    search.typeText(legend.label)
    legend.click()
    XCTAssertTrue(row.isSelected)
    let list = app.scrollViews.containing(.button, identifier: "Sort by RAM").firstMatch
    list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9)).click()
    XCTAssertFalse(row.isSelected)
    XCTAssertEqual(center.label, "Measured process total")

    legend.click()
    row.buttons.firstMatch.click()
    XCTAssertFalse(row.isSelected)
    XCTAssertEqual(center.label, "Measured process total")
  }

  @MainActor
  func testPieClickRevealsSelectedRowAndMovesKeyboardFocus() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-refreshInterval", "10", "-defaultSortOrder", "name"]
    app.launch()
    let legend = app.buttons.matching(
      NSPredicate(format: "identifier BEGINSWITH 'chart-legend:group:'")
    ).firstMatch
    XCTAssertTrue(legend.waitForExistence(timeout: 5))
    let groupID = String(legend.identifier.dropFirst("chart-legend:group:".count))
    let row = app.descendants(matching: .any)["work-unit:\(groupID)"]
    let search = app.searchFields["Search work units"]
    search.click()
    search.typeText("qz")

    let chart = app.descendants(matching: .any)["memory-pie-chart"]
    chart.coordinate(withNormalizedOffset: CGVector(dx: 0.505, dy: 0.1)).click()
    XCTAssertEqual(search.value as? String, "")
    XCTAssertTrue(row.waitForExistence(timeout: 3))
    XCTAssertTrue(row.isSelected)
    XCTAssertTrue(row.isHittable, "Chart selection must scroll the parent row into view")
    XCTAssertGreaterThanOrEqual(row.frame.minY, app.buttons["Sort by RAM"].frame.maxY)

    app.typeKey(.downArrow, modifierFlags: [])
    XCTAssertFalse(row.isSelected, "Arrow keys must move list selection after a chart click")
    legend.click()
    XCTAssertTrue(row.isSelected)
    app.scrollViews.containing(.button, identifier: "Sort by RAM").firstMatch
      .scroll(byDeltaX: 0, deltaY: -600)
    legend.click()
    XCTAssertFalse(row.isSelected, "Clicking the selected slice again must clear selection")
    legend.click()
    XCTAssertTrue(row.isSelected)
    XCTAssertTrue(row.isHittable, "Reselecting a slice must reveal its row")
    row.buttons.firstMatch.click()
    app.scrollViews.containing(.button, identifier: "Sort by RAM").firstMatch
      .scroll(byDeltaX: 0, deltaY: -600)
    legend.click()
    XCTAssertTrue(row.isHittable, "An expanded group's parent row must remain reachable")
    XCTAssertGreaterThanOrEqual(row.frame.minY, app.buttons["Sort by RAM"].frame.maxY)
  }

  @MainActor
  func testListSelectionAndHoverShareChartHighlight() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-refreshInterval", "10", "-defaultSortOrder", "memory"]
    app.launch()
    let legends = app.buttons.matching(
      NSPredicate(format: "identifier BEGINSWITH 'chart-legend:group:'"))
    XCTAssertTrue(legends.element(boundBy: 1).waitForExistence(timeout: 5))
    let first = app.buttons[legends.element(boundBy: 0).identifier]
    let second = app.buttons[legends.element(boundBy: 1).identifier]
    let groupID = String(first.identifier.dropFirst("chart-legend:group:".count))
    let row = app.descendants(matching: .any)["work-unit:\(groupID)"]
    row.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.5)).click()
    XCTAssertTrue(first.isSelected)
    let activeLabel = app.descendants(matching: .any)["chart-center"]
    XCTAssertEqual(activeLabel.label, first.label)

    second.hover()
    XCTAssertEqual(activeLabel.label, second.label)
    XCTAssertTrue(row.isSelected, "Hover must not change list selection")
    app.buttons["Sort by RAM"].hover()
    XCTAssertEqual(activeLabel.label, first.label, "Leaving hover restores the selected slice")
    XCTAssertTrue(first.isSelected)
    first.hover()
    app.typeKey(.downArrow, modifierFlags: [])
    XCTAssertTrue(second.isSelected)
    XCTAssertEqual(activeLabel.label, second.label, "A new list selection must replace stale hover")
    let otherRow = app.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH 'work-unit:'")
    ).element(boundBy: 8)
    otherRow.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.5)).click()
    XCTAssertEqual(activeLabel.label, "Other")
    first.hover()
    app.typeKey(.downArrow, modifierFlags: [])
    XCTAssertEqual(
      activeLabel.label, "Other", "Selection within Other must also replace stale hover")
  }

  @MainActor
  func testColumnsAlignWithAlwaysVisibleScrollbars() throws {
    try checkColumnAlignment(scrollbars: "Always")
  }

  @MainActor
  func testColumnsAlignWithOverlayScrollbars() throws {
    try checkColumnAlignment(scrollbars: "WhenScrolling")
  }

  @MainActor
  func testColumnsAlignWithOnlyRequiredColumns() throws {
    try checkColumnAlignment(scrollbars: "Always", optionalColumns: false)
  }

  @MainActor
  private func checkColumnAlignment(scrollbars: String, optionalColumns: Bool = true) throws {
    let app = XCUIApplication()
    app.launchArguments = [
      "-AppleShowScrollBars", scrollbars,
      "-showThreadsColumn", optionalColumns ? "YES" : "NO",
      "-showPIDColumn", "NO",
      "-showProcessCountColumn", optionalColumns ? "YES" : "NO",
      "-showArchitectureColumn", "NO",
    ]
    app.launch()

    let header = app.buttons["Sort by RAM"]
    let value = app.staticTexts["work-unit-ram-value"].firstMatch
    XCTAssertTrue(value.waitForExistence(timeout: 5))
    XCTAssertEqual(header.frame.maxX, value.frame.maxX, accuracy: 1)

    let headerY = header.frame.minY
    let list = app.scrollViews.containing(.button, identifier: "Sort by RAM").firstMatch
    list.scroll(byDeltaX: 0, deltaY: -400)
    XCTAssertTrue(header.isHittable, "Column header should remain pinned when scrolling")
    XCTAssertEqual(header.frame.minY, headerY, accuracy: 1)
  }

  @MainActor
  func testPhysicalRAMSummaryRemainsReachableInSmallWindow() throws {
    let app = XCUIApplication()
    app.launch()
    let window = app.windows["RAM Monitor"]
    XCTAssertTrue(window.waitForExistence(timeout: 3))
    let corner = window.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 1))
      .withOffset(CGVector(dx: -2, dy: -2))
    let target = window.coordinate(withNormalizedOffset: .zero)
      .withOffset(CGVector(dx: 818, dy: 518))
    corner.press(forDuration: 0.1, thenDragTo: target)

    let summary = app.descendants(matching: .any)["physical-ram-summary"]
    XCTAssertTrue(summary.waitForExistence(timeout: 5))
    app.scrollViews["memory-summary-scroll"].scroll(byDeltaX: 0, deltaY: -400)
    XCTAssertTrue(
      summary.isHittable, "Physical RAM summary should be reachable without shrinking the pie")
  }

  @MainActor
  func testMainWindowOpens() throws {
    let app = XCUIApplication()
    app.launch()

    XCTAssertTrue(app.windows["RAM Monitor"].waitForExistence(timeout: 3))
  }

  @MainActor
  func testMainWindowHasChartListAndSearch() throws {
    let app = XCUIApplication()
    app.launch()

    XCTAssertTrue(
      app.descendants(matching: .any)["memory-pie-chart"].waitForExistence(timeout: 3),
      "Memory pie chart is missing"
    )
    XCTAssertTrue(
      app.descendants(matching: .any)["work-unit-list"].waitForExistence(timeout: 5),
      "Work unit list is missing"
    )
    XCTAssertTrue(app.searchFields["Search work units"].exists, "Search field is missing")
    app.buttons["Sort by RAM"].hover()
    XCTAssertEqual(
      app.descendants(matching: .any)["chart-center"].label, "Measured process total")
    XCTAssertTrue(app.descendants(matching: .any)["physical-ram-summary"].exists)
  }

  @MainActor
  func testSettingsOpen() throws {
    let app = XCUIApplication()
    app.launch()

    app.typeKey(",", modifierFlags: .command)

    XCTAssertTrue(
      app.descendants(matching: .any)["settings-view"].waitForExistence(timeout: 3),
      "Settings view is missing"
    )
  }

  @MainActor
  func testGroupExpansionAndEmptySearchResult() throws {
    let app = XCUIApplication()
    app.launch()

    let expand = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Expand '")).firstMatch
    XCTAssertTrue(expand.waitForExistence(timeout: 5), "No expandable work unit is available")
    let collapseLabel = "Collapse \(String(expand.label.dropFirst("Expand ".count)))"
    expand.click()
    XCTAssertTrue(
      app.buttons[collapseLabel].waitForExistence(timeout: 2), "Work unit did not expand")

    let search = app.searchFields["Search work units"]
    XCTAssertTrue(search.exists, "Search field is missing")
    search.click()
    search.typeText("qz")
    XCTAssertTrue(
      app.descendants(matching: .any)["no-matching-work-units"].waitForExistence(timeout: 2),
      "Empty search result is missing"
    )
  }
}
