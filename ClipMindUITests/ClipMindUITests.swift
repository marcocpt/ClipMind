import XCTest

final class ClipMindUITests: XCTestCase {
    func testAppLaunches() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.exists, "ClipMind 应用应能启动")
    }
}
