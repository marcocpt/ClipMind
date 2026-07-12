import XCTest

final class SearchUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// 启动参数：显示主窗口 + 注入预览数据
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--UITEST_SHOW_MAIN_WINDOW", "--UITEST_PREVIEW_DATA"]
        app.launch()
        app.activate()
        return app
    }

    func testSearchBarExists() {
        let app = launchApp()

        let searchField = app.textFields["mainSearchField"]
        XCTAssertTrue(
            searchField.waitForExistence(timeout: 5),
            "主窗口应包含搜索框"
        )
    }

    func testSourceFilterExists() {
        let app = launchApp()

        // Picker 在 macOS 上可能不是 MenuButton，使用 descendants 兜底查询
        let sourceFilter = app.descendants(matching: .any)["sourceFilterPicker"].firstMatch
        XCTAssertTrue(
            sourceFilter.waitForExistence(timeout: 5),
            "主窗口应包含来源筛选器"
        )
    }

    func testSearchReturnsResults() {
        let app = launchApp()

        let searchField = app.textFields["mainSearchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))

        searchField.tap()
        searchField.typeText("viewDidLoad")

        // 等待防抖 300ms + 搜索执行；List 在 macOS 上可能不是 otherElements
        let resultsList = app.descendants(matching: .any)["searchResultsList"].firstMatch
        XCTAssertTrue(
            resultsList.waitForExistence(timeout: 3),
            "搜索后应显示结果列表"
        )
    }

    func testSearchNoMatchShowsEmptyState() {
        let app = launchApp()

        let searchField = app.textFields["mainSearchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))

        searchField.tap()
        searchField.typeText("zzz_no_match_zzz")

        // 等待防抖 + 搜索执行
        let emptyState = app.staticTexts["未找到匹配内容"]
        XCTAssertTrue(
            emptyState.waitForExistence(timeout: 3),
            "无匹配结果时应显示空状态"
        )
    }

    func testClearSearchButtonVisibleWhenTextExists() {
        let app = launchApp()

        let searchField = app.textFields["mainSearchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))

        searchField.tap()
        searchField.typeText("test")

        let clearButton = app.buttons["clearSearchButton"]
        XCTAssertTrue(
            clearButton.waitForExistence(timeout: 3),
            "有输入文本时应显示清除按钮"
        )
    }
}
