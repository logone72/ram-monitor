import XCTest

final class RAMMonitorUITests: XCTestCase {
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
