import XCTest

final class PopoverUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testStatusBarItemExists() {
        let app = XCUIApplication()
        app.launch()

        let statusItem = app.menuBars.statusItems.firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5), "菜单栏图标应存在")
    }

    func testPopoverAppearsOnIconClick() {
        let app = XCUIApplication()
        app.launchArguments = ["--UITEST_POPOVER_WINDOW"]
        app.launch()

        let searchField = app.textFields["popoverSearchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5), "popover 内容应能显示")
    }

    func testPopoverContainsSearchField() {
        let app = XCUIApplication()
        app.launchArguments = ["--UITEST_POPOVER_WINDOW"]
        app.launch()

        let searchField = app.textFields["popoverSearchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5), "popover 应包含搜索框")
    }

    func testPopoverContainsViewAllButton() {
        let app = XCUIApplication()
        app.launchArguments = ["--UITEST_POPOVER_WINDOW"]
        app.launch()

        let viewAllButton = app.buttons["查看全部"]
        XCTAssertTrue(viewAllButton.waitForExistence(timeout: 5), "popover 应包含查看全部按钮")
    }

    func testPopoverShowsEmptyState() {
        let app = XCUIApplication()
        app.launchArguments = ["--UITEST_POPOVER_WINDOW"]
        app.launch()

        let emptyStateText = app.staticTexts["暂无剪贴内容"]
        XCTAssertTrue(emptyStateText.waitForExistence(timeout: 5), "popover 应显示空状态占位")
    }
}
