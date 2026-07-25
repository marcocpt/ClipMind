import XCTest

final class MainWindowUITests: XCTestCase {
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

    /// 验证主窗口列表行单击后详情面板更新（F1.11 后续 bug 修复）。
    ///
    /// Bug：HistoryListView 创建 ClipRowView 时未传 onSingleClick，
    /// ClipRowView 内部 .onTapGesture(count: 1) 吞掉点击事件但不执行任何操作，
    /// 外层 .onTapGesture { selectedClip = clip } 不触发，导致详情面板不更新。
    ///
    /// 修复：HistoryListView 与 UnifiedPastePanelView 对齐，将选中回调注入
    /// ClipRowView 的 onSingleClick 参数。
    func testMainWindowListClick_UpdatesDetailPanel() {
        let app = XCUIApplication()
        app.launchArguments = ["--UITEST_SHOW_MAIN_WINDOW", "--UITEST_PREVIEW_DATA"]
        app.launch()
        app.activate()

        // 初始详情面板应显示空状态文本
        let emptyDetailText = app.staticTexts["选择一条剪贴内容查看详情"]
        XCTAssertTrue(
            emptyDetailText.waitForExistence(timeout: 5),
            "初始详情面板应显示空状态"
        )

        // 点击列表第一行（包含预览数据首条文本 "func viewDidLoad() { super.viewDidLoad() }"）
        let firstRowText = app.staticTexts["func viewDidLoad() { super.viewDidLoad() }"]
        XCTAssertTrue(
            firstRowText.waitForExistence(timeout: 3),
            "第一行应包含预览文本"
        )
        firstRowText.click()

        // 修复前：selectedClip 不更新，空状态文本不消失
        // 修复后：onSingleClick 触发 selectedClip = clip，详情面板更新
        let emptyDetailGone = NSPredicate(format: "exists == NO")
        let expectation = XCTNSPredicateExpectation(
            predicate: emptyDetailGone,
            object: emptyDetailText
        )
        wait(for: [expectation], timeout: 2.0)
        XCTAssertFalse(
            emptyDetailText.exists,
            "点击行后详情面板应更新，空状态文本应消失"
        )
    }

    /// 验证侧边栏最小宽度为 350pt（F1.12: 原 700 太宽导致窗口缩小时内容溢出）。
    ///
    /// NavigationView 内的 VStack 无法被 XCUITest 直接定位，通过详情面板空状态文本
    /// 的居中位置反推侧边栏宽度：
    /// sidebar_width ≈ 2 * (text.midX - window.minX) - window.width - divider
    func testSidebarMinWidth350() {
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
            sidebarWidth, 350,
            "侧边栏宽度应至少为 350pt，实际约为 \(sidebarWidth)pt"
        )
    }
}
