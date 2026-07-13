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

    /// 验证侧边栏最小宽度为 700pt（bug: 侧边栏宽度太窄）。
    ///
    /// NavigationView 内的 VStack 无法被 XCUITest 直接定位，通过详情面板空状态文本
    /// 的居中位置反推侧边栏宽度：
    /// sidebar_width ≈ 2 * (text.midX - window.minX) - window.width - divider
    func testSidebarMinWidth700() {
        let app = XCUIApplication()
        app.launchArguments = ["--UITEST_SHOW_MAIN_WINDOW"]
        app.launch()
        app.activate()

        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5), "主窗口应存在")

        let detailText = app.staticTexts["选择一条剪贴内容查看详情"]
        XCTAssertTrue(detailText.waitForExistence(timeout: 5), "详情面板空状态文本应存在")

        let dividerWidth: CGFloat = 1
        let textMidX = detailText.frame.midX
        let windowMinX = window.frame.minX
        let windowWidth = window.frame.width
        let sidebarWidth = 2 * (textMidX - windowMinX) - windowWidth - dividerWidth

        XCTAssertGreaterThanOrEqual(
            sidebarWidth, 700,
            "侧边栏宽度应至少为 700pt，实际约为 \(sidebarWidth)pt"
        )
    }
}
