import XCTest

final class RAMMonitorUITests: XCTestCase {
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
    XCTAssertTrue(app.staticTexts["Measured process total"].exists)
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
