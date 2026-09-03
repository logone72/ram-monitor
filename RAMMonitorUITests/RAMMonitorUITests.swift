import XCTest

final class RAMMonitorUITests: XCTestCase {
  @MainActor
  func testMainWindowOpens() throws {
    let app = XCUIApplication()
    app.launch()

    XCTAssertTrue(app.windows["RAM Monitor"].waitForExistence(timeout: 3))
  }
}
