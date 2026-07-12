import XCTest

final class MainWindowUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testMainWindowOpens() {
        let app = XCUIApplication()
        app.launchArguments = ["--UITEST_SHOW_MAIN_WINDOW"]
        app.launch()
        app.activate()

        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 5), "主窗口应能打开")
    }

    func testMainWindowContainsHistoryList() {
        let app = XCUIApplication()
        app.launchArguments = ["--UITEST_SHOW_MAIN_WINDOW"]
        app.launch()
        app.activate()

        let subtitle = app.staticTexts["复制任何内容，它将自动出现在这里"]
        XCTAssertTrue(subtitle.waitForExistence(timeout: 5), "主窗口应包含历史列表区域")
    }

    func testMainWindowShowsEmptyState() {
        let app = XCUIApplication()
        app.launchArguments = ["--UITEST_SHOW_MAIN_WINDOW"]
        app.launch()
        app.activate()

        let emptyStateText = app.staticTexts["暂无剪贴历史"]
        XCTAssertTrue(emptyStateText.waitForExistence(timeout: 5), "主窗口应显示空状态")
    }

    func testMainWindowContainsSettingsButton() {
        let app = XCUIApplication()
        app.launchArguments = ["--UITEST_SHOW_MAIN_WINDOW"]
        app.launch()
        app.activate()

        let settingsButton = app.buttons["settingsButton"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5), "主窗口应包含设置按钮")
    }
}
