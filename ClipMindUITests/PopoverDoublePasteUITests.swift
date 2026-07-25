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

// MARK: - AC-F1.11-1 边界用例：空列表无高亮

extension PopoverDoublePasteUITests
{
    /// 验证菜单栏弹窗打开时列表为空无高亮（边界用例）。
    /// 不注入 `--UITEST_PREVIEW_DATA`，clips 为空数组，selectedIndex = -1。
    func test05_EmptyClips_NoHighlight()
    {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_POPOVER_WINDOW"
        ]
        app.launch()

        let searchField = app.textFields["popoverSearchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5), "弹窗应出现")

        // 空列表不应存在任何 selected 标识符的行
        XCTAssertFalse(
            app.descendants(matching: .any)["popoverRow_0_selected"].firstMatch.exists,
            "空列表不应有高亮行"
        )
        XCTAssertFalse(
            app.descendants(matching: .any)["popoverRow_0"].firstMatch.exists,
            "空列表不应有任何行"
        )
    }
}

// MARK: - AC-F1.11-9 图片 / 文件路径双击提示

extension PopoverDoublePasteUITests
{
    /// 验证双击图片类型行显示「仅支持文本粘贴」提示。
    /// 预置顺序（timestamp 降序）：image（row 0）→ filePath（row 1）→ text（row 2）。
    func test06_DoubleClickImageRow_ShowsTextOnlyHint()
    {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_POPOVER_WINDOW",
            "--UITEST_PREPOPULATE_IMAGE_AND_FILEPATH"
        ]
        app.launch()

        let searchField = app.textFields["popoverSearchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))

        // image 在 row 0（默认高亮，identifier 带 _selected 后缀）
        let imageRow = app.descendants(matching: .any)["popoverRow_0_selected"].firstMatch
        XCTAssertTrue(imageRow.waitForExistence(timeout: 3), "图片行应存在")
        imageRow.doubleClick()

        // 应显示提示
        let hint = app.staticTexts["textOnlyHint"].firstMatch
        XCTAssertTrue(hint.waitForExistence(timeout: 3), "图片类型双击应显示提示")

        // 弹窗不应关闭（搜索框仍存在）
        XCTAssertTrue(searchField.exists, "图片类型双击不关闭弹窗")
    }

    /// 验证双击文件路径类型行显示「仅支持文本粘贴」提示。
    func test07_DoubleClickFilePathRow_ShowsTextOnlyHint()
    {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_POPOVER_WINDOW",
            "--UITEST_PREPOPULATE_IMAGE_AND_FILEPATH"
        ]
        app.launch()

        let searchField = app.textFields["popoverSearchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.click()

        // filePath 在 row 1（非默认高亮，identifier 不带 _selected 后缀）
        let filePathRow = app.descendants(matching: .any)["popoverRow_1"].firstMatch
        XCTAssertTrue(filePathRow.waitForExistence(timeout: 3), "文件路径行应存在")
        filePathRow.doubleClick()

        let hint = app.staticTexts["textOnlyHint"].firstMatch
        XCTAssertTrue(hint.waitForExistence(timeout: 3), "文件路径类型双击应显示提示")
    }

    /// 验证提示后单击其他行可清除提示。
    func test08_HintDismissedAfterClickingOtherRow()
    {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_POPOVER_WINDOW",
            "--UITEST_PREPOPULATE_IMAGE_AND_FILEPATH"
        ]
        app.launch()

        let searchField = app.textFields["popoverSearchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.click()

        // 双击 image 行（row 0）显示提示
        let imageRow = app.descendants(matching: .any)["popoverRow_0_selected"].firstMatch
        XCTAssertTrue(imageRow.waitForExistence(timeout: 3))
        imageRow.doubleClick()

        let hint = app.staticTexts["textOnlyHint"].firstMatch
        XCTAssertTrue(hint.waitForExistence(timeout: 3), "应显示提示")

        // 单击 text 行（row 2）应清除提示
        let textRow = app.descendants(matching: .any)["popoverRow_2"].firstMatch
        XCTAssertTrue(textRow.waitForExistence(timeout: 3), "文本行应存在")
        textRow.click()

        // 等待提示消失
        let hintCleared = NSPredicate(format: "exists == NO")
        let expectation = XCTNSPredicateExpectation(predicate: hintCleared, object: hint)
        wait(for: [expectation], timeout: 3.0)
        XCTAssertFalse(hint.exists, "点击其他行后提示应清除")
    }
}
