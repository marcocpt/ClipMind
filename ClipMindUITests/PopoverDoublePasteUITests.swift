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

    /// 清理 EncryptedStore 数据库，避免上次测试残留数据干扰预置数据顺序。
    /// 仅在使用 `--UITEST_PREPOPULATE_IMAGE_AND_FILEPATH` 的测试（test06-08）中调用，
    /// 确保调用时上一轮应用已 terminate，避免删除正在使用的数据库文件导致应用崩溃。
    /// 沿用 F1.9 `QuickPasteOverlayUITests.cleanUpDatabase` 的实现方式。
    private func cleanUpDatabase()
    {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        let dbPath = appSupport.appendingPathComponent("ClipMind/clipmind.db")
        for suffix in ["", "-wal", "-shm"]
        {
            try? FileManager.default.removeItem(atPath: dbPath.path + suffix)
        }
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
        app.activate()

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
        app.activate()

        let searchField = app.textFields["popoverSearchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.click()

        let firstRowSelected = app.descendants(matching: .any)["popoverRow_0_selected"].firstMatch
        XCTAssertTrue(firstRowSelected.waitForExistence(timeout: 3), "初始第一行应高亮")

        // 按方向键下（先激活应用，避免连续 typeKey 将应用切到后台）
        app.activate()
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
        app.activate()

        let searchField = app.textFields["popoverSearchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.click()

        let firstRowSelected = app.descendants(matching: .any)["popoverRow_0_selected"].firstMatch
        XCTAssertTrue(firstRowSelected.waitForExistence(timeout: 3))

        // 方向键下 → 方向键上（每次按键前激活应用，避免连续 typeKey 触发窗口管理将应用切到后台）
        app.activate()
        searchField.typeKey(XCUIKeyboardKey.downArrow, modifierFlags: [])
        app.activate()
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
        app.activate()

        let searchField = app.textFields["popoverSearchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.click()

        // 按 Esc 键（先激活应用，避免 typeKey 将应用切到后台）
        app.activate()
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
        app.activate()

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
// test06-08 已拆分到 `PopoverHintUITests.swift`，避免单文件超过 SwiftLint `file_length` 500 行限制。

// MARK: - AC-F1.11-4 方向键导航边界用例

extension PopoverDoublePasteUITests
{
    /// 验证第一行按方向键上不动（边界用例）。
    func test09_ArrowUpAtFirstRow_StaysAtFirst()
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
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        app.activate()
        searchField.click()

        let firstRowSelected = app.descendants(matching: .any)["popoverRow_0_selected"].firstMatch
        XCTAssertTrue(firstRowSelected.waitForExistence(timeout: 3), "初始第一行应高亮")

        // 第一行按方向键上，应保持在第一行（先激活应用，避免 typeKey 将应用切到后台）
        app.activate()
        searchField.typeKey(XCUIKeyboardKey.upArrow, modifierFlags: [])
        XCTAssertTrue(
            app.descendants(matching: .any)["popoverRow_0_selected"].firstMatch.exists,
            "首行按上应保持不动"
        )
    }

    /// 验证最后一行按方向键下不动（边界用例）。
    /// 使用 `--UITEST_PREVIEW_DATA_SMALL`（3 条确定性数据），避免 11 条数据下连续按 10 次方向键
    /// 触发 LazyVStack 滚动渲染卡顿（实测在按下第 6 次时 app idle 等待超过 10 秒）。
    /// 3 条数据下只需按 2 次方向键即到达末行（index=2），再按下应保持不动。
    /// 每次按键前 `app.activate()` 确保应用前台状态，避免连续 typeKey 触发 macOS 窗口管理
    /// 将应用切到后台（实测第二次 typeKey 时报 "Application is not foreground"）。
    func test10_ArrowDownAtLastRow_StaysAtLast()
    {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_POPOVER_WINDOW",
            "--UITEST_PREVIEW_DATA_SMALL"
        ]
        app.launch()

        let searchField = app.textFields["popoverSearchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.click()

        // previewClips 前 3 条，索引 0~2，按 2 次下到达最后一行
        let lastIndex = 2
        for rowIndex in 1...lastIndex
        {
            app.activate()
            searchField.click()
            searchField.typeKey(XCUIKeyboardKey.downArrow, modifierFlags: [])
            let expectedRow = app.descendants(matching: .any)["popoverRow_\(rowIndex)_selected"].firstMatch
            XCTAssertTrue(
                expectedRow.waitForExistence(timeout: 2),
                "按下后第 \(rowIndex) 行应高亮"
            )
        }

        // 再按下不动
        app.activate()
        searchField.click()
        searchField.typeKey(XCUIKeyboardKey.downArrow, modifierFlags: [])
        XCTAssertTrue(
            app.descendants(matching: .any)["popoverRow_\(lastIndex)_selected"].firstMatch.exists,
            "末行按下应保持不动"
        )
    }
}

// MARK: - AC-F1.11-5 Esc 键不写入剪贴板

extension PopoverDoublePasteUITests
{
    /// 验证 Esc 键关闭菜单栏弹窗时不修改剪贴板内容。
    func test11_EscKey_DoesNotModifyClipboard()
    {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_POPOVER_WINDOW",
            "--UITEST_PREVIEW_DATA"
        ]
        app.launch()
        app.activate()

        // 预置剪贴板内容
        let pasteboard = NSPasteboard.general
        let originalContent = "ORIGINAL_CLIPBOARD_CONTENT"
        pasteboard.clearContents()
        pasteboard.setString(originalContent, forType: .string)

        let searchField = app.textFields["popoverSearchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.click()

        // 按 Esc 键（先激活应用，避免 typeKey 将应用切到后台）
        app.activate()
        searchField.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])

        // 等待弹窗关闭
        let panelClosed = NSPredicate(format: "exists == NO")
        let expectation = XCTNSPredicateExpectation(predicate: panelClosed, object: searchField)
        wait(for: [expectation], timeout: 3.0)

        // 验证剪贴板内容不变
        let currentContent = pasteboard.string(forType: .string)
        XCTAssertEqual(currentContent, originalContent, "Esc 键不应修改剪贴板内容")
    }
}

// MARK: - AC-F1.11-2 / AC-F1.11-3 双击 / 回车触发粘贴回调

extension PopoverDoublePasteUITests
{
    /// 验证双击文本行触发 onPasteTriggered 回调。
    ///
    /// 不使用 `--UITEST_FORCE_NO_PERMISSION`，沿用 F1.9 `testDoubleClick_OnTextRow_TriggersPaste`
    /// 的端到端验证模式：`onPasteTriggered` 触发后会关闭面板（PopoverPreviewWindowFactory
    /// 默认注入 `viewModel.onPasteTriggered = { window?.close() }`），通过搜索框消失证明回调被调用。
    /// 文本行才会触发回调（图片 / 文件路径行只显示提示），因此面板关闭是文本行回调触发的可靠信号。
    func test12_DoubleClickTextRow_TriggersPasteCallback()
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
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))

        // previewClips 第一条是文本类型，双击应触发回调（关闭面板）
        let firstRow = app.descendants(matching: .any)["popoverRow_0_selected"].firstMatch
        XCTAssertTrue(firstRow.waitForExistence(timeout: 3), "第一行应存在")
        firstRow.doubleClick()

        // 面板关闭验证（搜索框消失）——证明 onPasteTriggered 回调被触发
        let panelClosedExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == NO"),
            object: searchField
        )
        wait(for: [panelClosedExpectation], timeout: 3.0)
        XCTAssertFalse(searchField.exists, "双击文本行触发回调后面板应关闭")
    }

    /// 验证回车键触发选中行粘贴回调。
    ///
    /// 沿用 F1.9 `testEnterKey_TriggersPaste` 的端到端验证模式：回车触发 `onPasteTriggered`
    /// 后关闭面板，通过搜索框消失证明回调被调用。
    func test13_EnterKey_TriggersPasteCallback()
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
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.click()

        // 第一行默认高亮，直接按回车（先激活应用，避免 typeKey 将应用切到后台）
        app.activate()
        searchField.typeKey(XCUIKeyboardKey.return, modifierFlags: [])

        // 面板关闭验证（搜索框消失）——证明 onPasteTriggered 回调被触发
        let panelClosedExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == NO"),
            object: searchField
        )
        wait(for: [panelClosedExpectation], timeout: 3.0)
        XCTAssertFalse(searchField.exists, "回车触发回调后面板应关闭")
    }

    /// 验证空列表按回车不触发回调（边界用例）。
    ///
    /// 空列表时 `selectedIndex = -1`，`handleEnterKey` 的 `guard` 提前返回，
    /// 不调用 `onPasteTriggered`，面板保持打开。
    func test14_EnterKey_OnEmptyClips_DoesNotTrigger()
    {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_POPOVER_WINDOW"
        ]
        app.launch()
        app.activate()

        let searchField = app.textFields["popoverSearchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.click()

        // 空列表回车（先激活应用，避免 typeKey 将应用切到后台）
        app.activate()
        searchField.typeKey(XCUIKeyboardKey.return, modifierFlags: [])

        // 验证面板未关闭：1 秒内搜索框不应消失（反向期望，避免固定 sleep）
        let panelClosedExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == NO"),
            object: searchField
        )
        panelClosedExpectation.isInverted = true
        wait(for: [panelClosedExpectation], timeout: 1.0)
        XCTAssertTrue(searchField.exists, "空列表回车不应触发回调，面板应保持打开")
    }
}
