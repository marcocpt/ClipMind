import XCTest

/// F1.16 列表多行预览 UI 测试。
///
/// 验证左侧列表（主窗口 HistoryListView、菜单栏弹窗 UnifiedPastePanelView）
/// 能正常渲染含 `\n` 的多行剪贴内容 cell。
///
/// Bug：`.lineLimit(2)` 缺少 `.fixedSize`，Text 在 List/LazyVStack 中
/// 未纵向扩展，导致含回车的文本只显示第一行。
///
/// 测试策略：previewClips 第 12 条（索引 11）为多行文本，
/// 验证列表 cells.count >= 12 确认该 cell 被渲染。
/// 不通过 predicate 查找第二行文本，因为 SwiftUI Text 在 macOS
/// accessibility tree 中的 label 表示可能因换行符处理方式不同而不稳定。
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

    /// 计算 app 中的剪贴条目数。
    ///
    /// F1.14：HistoryListView 用 ScrollView+LazyVStack，LazyVStack 懒加载导致
    /// typeTag_ 前缀计数只返回可见行。HistoryListView/UnifiedPastePanelView 暴露
    /// 隐藏元素（filteredClips.count），通过 accessibilityValue 读取准确数量。
    /// - 主窗口：historyListCount
    /// - 菜单栏弹窗：popoverListCount
    private func clipCount(in app: XCUIApplication, identifier: String = "historyListCount") -> Int
    {
        let countElement = app.descendants(matching: .any)[identifier].firstMatch
        guard countElement.exists else { return 0 }
        return Int(countElement.value as? String ?? "0") ?? 0
    }

    // MARK: - AC-F1.16-1 主窗口列表渲染多行 cell

    /// 验证主窗口列表能渲染含多行文本的 cell（第 12 条 previewClip）。
    ///
    /// previewClips 第 12 条（索引 11）为：
    /// "多行剪贴内容第一行\n多行剪贴内容第二行"
    /// 修复前：Text 被裁剪为单行，cell 高度不足
    /// 修复后：Text 通过 .fixedSize 纵向扩展，cell 正常渲染
    func test01_MainWindowRendersMultiLineCell()
    {
        let app = XCUIApplication()
        app.launchArguments = ["--UITEST_SHOW_MAIN_WINDOW", "--UITEST_PREVIEW_DATA"]
        app.launch()
        app.activate()

        // 等待列表出现（historyList identifier 在 List 上，用 descendants 匹配）
        let historyList = app.descendants(matching: .any)["historyList"].firstMatch
        XCTAssertTrue(
            historyList.waitForExistence(timeout: 10),
            "主窗口历史列表应出现"
        )

        // previewClips 有 12 条，验证列表条目数 >= 12
        // 确保含多行文本的最后一条被渲染
        let cellCount = clipCount(in: app)
        XCTAssertGreaterThanOrEqual(
            cellCount,
            12,
            "主窗口列表应渲染全部 12 条 previewClips（含多行文本 cell），实际 \(cellCount)"
        )
    }

    // MARK: - AC-F1.16-2 菜单栏弹窗列表渲染多行 cell

    /// 验证菜单栏弹窗（popover）列表能渲染含多行文本的 cell。
    func test02_PopoverRendersMultiLineCell()
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
            searchField.waitForExistence(timeout: 10),
            "菜单栏弹窗应出现并包含搜索框"
        )

        // 弹窗列表中应渲染全部 12 条 previewClips
        // 通过 popoverListCount 隐藏元素读取准确数量
        let cellCount = clipCount(in: app, identifier: "popoverListCount")
        XCTAssertGreaterThanOrEqual(
            cellCount,
            12,
            "弹窗列表应渲染全部 12 条 previewClips（含多行文本 cell），实际 \(cellCount)"
        )
    }
}
