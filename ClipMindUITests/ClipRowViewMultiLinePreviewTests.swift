import XCTest

/// F1.16 列表多行预览 UI 测试。
///
/// 验证左侧列表（主窗口 HistoryListView）中含 `\n` 的剪贴内容预览显示最多两行，
/// 第二行文本应在列表中可见。
///
/// Bug：`.lineLimit(2)` 已设置但缺少 `.fixedSize`，Text 在 List/LazyVStack 中
/// 未纵向扩展，导致含回车的文本只显示第一行。
final class ClipRowViewMultiLinePreviewTests: XCTestCase
{
    override func setUp()
    {
        super.setUp()
        continueAfterFailure = false
    }

    override func tearDown()
    {
        XCUIApplication().terminate()
        super.tearDown()
    }

    // MARK: - AC-F1.16-1 主窗口列表多行预览显示第二行

    /// 验证主窗口列表中多行剪贴内容的第二行文本可见。
    ///
    /// previewClips 第 12 条（索引 11）为多行文本：
    /// "多行剪贴内容第一行\n多行剪贴内容第二行"
    /// 修复前：Text 仅显示第一行，第二行被裁剪
    /// 修复后：Text 显示两行，第二行 "多行剪贴内容第二行" 应作为 staticText 可见
    func test01_MainWindowMultiLinePreview_ShowsSecondLine()
    {
        let app = XCUIApplication()
        app.launchArguments = ["--UITEST_SHOW_MAIN_WINDOW", "--UITEST_PREVIEW_DATA"]
        app.launch()
        app.activate()

        // 等待列表出现
        let historyList = app.scrollViews["historyList"]
        XCTAssertTrue(
            historyList.waitForExistence(timeout: 5),
            "主窗口历史列表应出现"
        )

        // 多行剪贴内容的第二行文本应在列表中可见
        // 修复前：Text 被裁剪为单行，第二行不可见
        // 修复后：Text 显示两行，第二行 "多行剪贴内容第二行" 可见
        let secondLineText = app.staticTexts["多行剪贴内容第二行"]
        XCTAssertTrue(
            secondLineText.waitForExistence(timeout: 5),
            "多行剪贴内容的第二行应在列表中可见"
        )
    }

    // MARK: - AC-F1.16-2 菜单栏弹窗列表多行预览显示第二行

    /// 验证菜单栏弹窗（popover）列表中多行剪贴内容的第二行文本可见。
    func test02_PopoverMultiLinePreview_ShowsSecondLine()
    {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_POPOVER_WINDOW",
            "--UITEST_PREVIEW_DATA"
        ]
        app.launch()
        app.activate()

        let searchField = app.textFields["popoverSearchField"]
        XCTAssertTrue(
            searchField.waitForExistence(timeout: 5),
            "菜单栏弹窗应出现并包含搜索框"
        )

        // 多行剪贴内容的第二行文本应在弹窗列表中可见
        let secondLineText = app.staticTexts["多行剪贴内容第二行"]
        XCTAssertTrue(
            secondLineText.waitForExistence(timeout: 5),
            "多行剪贴内容的第二行应在弹窗列表中可见"
        )
    }
}
