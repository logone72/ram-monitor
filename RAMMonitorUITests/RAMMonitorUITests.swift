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
}
