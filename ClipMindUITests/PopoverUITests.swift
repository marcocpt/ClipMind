import XCTest

final class PopoverUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        cleanUpDatabase()
    }

    override func tearDown() {
        XCUIApplication().terminate()
        super.tearDown()
    }

    /// 清除上一轮测试残留的数据库文件（F1.8 示例数据注入后需清理）。
    private func cleanUpDatabase() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        let dbPath = appSupport.appendingPathComponent("ClipMind/clipmind.db")
        for suffix in ["", "-wal", "-shm"] {
            try? FileManager.default.removeItem(atPath: dbPath.path + suffix)
        }
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

    // MARK: - T1.8: 类型标签 UI 验证

    /// 查找类型标签元素。
    /// TypeTagView 的 accessibilityIdentifier 应用在 Text 上，
    /// 在 macOS XCUITest 中可能被识别为 staticTexts 或 otherElements，
    /// 使用 descendants(matching: .any) 兜底两种情况。
    private func typeTag(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    func testPopoverShowsTypeTagsWithPreviewData() {
        let app = XCUIApplication()
        app.launchArguments = ["--UITEST_POPOVER_WINDOW", "--UITEST_PREVIEW_DATA"]
        app.launch()

        // 验证 CODE 类型标签存在
        let codeTag = typeTag("typeTag_code", in: app)
        XCTAssertTrue(
            codeTag.waitForExistence(timeout: 5),
            "popover 应显示 CODE 类型标签"
        )
    }

    func testPopoverShowsMultipleTypeTags() {
        let app = XCUIApplication()
        app.launchArguments = ["--UITEST_POPOVER_WINDOW", "--UITEST_PREVIEW_DATA"]
        app.launch()

        // 验证多种类型标签存在
        let codeTag = typeTag("typeTag_code", in: app)
        let linkTag = typeTag("typeTag_link", in: app)
        let errorTag = typeTag("typeTag_error", in: app)

        XCTAssertTrue(codeTag.waitForExistence(timeout: 5), "应显示 CODE 标签")
        XCTAssertTrue(linkTag.waitForExistence(timeout: 5), "应显示 LINK 标签")
        XCTAssertTrue(errorTag.waitForExistence(timeout: 5), "应显示 ERROR 标签")
    }

    func testPopoverSearchFiltersClipsByContent() {
        let app = XCUIApplication()
        app.launchArguments = ["--UITEST_POPOVER_WINDOW", "--UITEST_PREVIEW_DATA"]
        app.launch()

        let searchField = app.textFields["popoverSearchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))

        // 输入查询过滤
        searchField.tap()
        searchField.typeText("viewDidLoad")

        // 验证 CODE 标签仍存在（匹配的条目）
        let codeTag = typeTag("typeTag_code", in: app)
        XCTAssertTrue(codeTag.waitForExistence(timeout: 3), "过滤后应显示匹配的 CODE 条目")
    }
}
