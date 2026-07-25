import AppKit
import XCTest

/// 菜单栏弹窗双击粘贴 UI 测试（F1.11 Phase 2 任务 2 ~ 任务 6）。
///
/// 通过 `--UITEST_POPOVER_WINDOW` 启动参数在独立 NSWindow 中承载 UnifiedPastePanelView，
/// 使 XCUITest 能稳定定位元素（沿用 F1.9 测试模式）。
/// 通过 `--UITEST_PREVIEW_DATA` 注入 ClipTestData.previewClips（11 条文本数据）。
final class PopoverDoublePasteUITests: XCTestCase
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

    // MARK: - AC-F1.11-1 菜单栏弹窗打开后默认高亮第一行

    /// 验证菜单栏弹窗场景下默认高亮第一行（与 F1.9 快捷键面板行为对齐）。
    func test01_PopoverDefaultHighlightFirstRow()
    {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_POPOVER_WINDOW",
            "--UITEST_PREVIEW_DATA"
        ]
        app.launch()

        let searchField = app.textFields["popoverSearchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5), "菜单栏弹窗应出现并包含搜索框")

        // 第一行应高亮（标识符包含 _selected 后缀）
        let firstRowSelected = app.descendants(matching: .any)["popoverRow_0_selected"].firstMatch
        XCTAssertTrue(
            firstRowSelected.waitForExistence(timeout: 3),
            "第一行应默认高亮"
        )
    }

    // MARK: - AC-F1.11-4 方向键下移动高亮行

    /// 验证方向键下移动高亮到第二行，第一行取消高亮。
    func test02_ArrowDown_MovesHighlightToSecondRow()
    {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_POPOVER_WINDOW",
            "--UITEST_PREVIEW_DATA"
        ]
        app.launch()

        let searchField = app.textFields["popoverSearchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.click()

        let firstRowSelected = app.descendants(matching: .any)["popoverRow_0_selected"].firstMatch
        XCTAssertTrue(firstRowSelected.waitForExistence(timeout: 3), "初始第一行应高亮")

        // 按方向键下
        searchField.typeKey(XCUIKeyboardKey.downArrow, modifierFlags: [])

        // 第二行应高亮，第一行取消高亮
        let secondRowSelected = app.descendants(matching: .any)["popoverRow_1_selected"].firstMatch
        XCTAssertTrue(
            secondRowSelected.waitForExistence(timeout: 3),
            "第二行应高亮"
        )
        XCTAssertFalse(
            app.descendants(matching: .any)["popoverRow_0_selected"].firstMatch.exists,
            "第一行应取消高亮"
        )
    }

    // MARK: - AC-F1.11-4 方向键上移动高亮行（反向导航）

    /// 验证方向键下后按上能回到第一行。
    func test03_ArrowUp_MovesHighlightBackToFirstRow()
    {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_POPOVER_WINDOW",
            "--UITEST_PREVIEW_DATA"
        ]
        app.launch()

        let searchField = app.textFields["popoverSearchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.click()

        let firstRowSelected = app.descendants(matching: .any)["popoverRow_0_selected"].firstMatch
        XCTAssertTrue(firstRowSelected.waitForExistence(timeout: 3))

        // 方向键下 → 方向键上
        searchField.typeKey(XCUIKeyboardKey.downArrow, modifierFlags: [])
        searchField.typeKey(XCUIKeyboardKey.upArrow, modifierFlags: [])

        XCTAssertTrue(
            app.descendants(matching: .any)["popoverRow_0_selected"].firstMatch.waitForExistence(timeout: 3),
            "应回到第一行高亮"
        )
    }

    // MARK: - AC-F1.11-5 Esc 键关闭菜单栏弹窗

    /// 验证 Esc 键关闭菜单栏弹窗（搜索框不再存在）。
    func test04_EscKey_ClosesPopover()
    {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_POPOVER_WINDOW",
            "--UITEST_PREVIEW_DATA"
        ]
        app.launch()

        let searchField = app.textFields["popoverSearchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.click()

        // 按 Esc 键
        searchField.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])

        // 弹窗应关闭（搜索框不再存在）
        let panelClosedExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == NO"),
            object: searchField
        )
        wait(for: [panelClosedExpectation], timeout: 3.0)
        XCTAssertFalse(searchField.exists, "Esc 键应关闭弹窗")
    }
}
