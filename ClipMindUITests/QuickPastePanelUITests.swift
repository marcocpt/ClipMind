import AppKit
import XCTest

final class QuickPastePanelUITests: XCTestCase
{
    override func setUp()
    {
        super.setUp()
        continueAfterFailure = false
        cleanUpDatabase()
    }

    override func tearDown()
    {
        XCUIApplication().terminate()
        super.tearDown()
    }

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
        // 清除面板位置记忆（避免上次关闭位置干扰测试）
        UserDefaults.standard.removeObject(forKey: "F1.9.quickPaste.lastClosedPositionX")
        UserDefaults.standard.removeObject(forKey: "F1.9.quickPaste.lastClosedPositionY")
    }

    // MARK: - TC-F1.9-1-01 全局快捷键呼出快速粘贴面板（非主窗口）

    /// 使用 --UITEST_QUICK_PASTE_PANEL 启动参数直接显示面板（绕过全局快捷键注册，
    /// 全局快捷键在 CI 环境无法可靠触发）。
    func testQuickPastePanelAppears_OnLaunchArgument()
    {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_QUICK_PASTE_PANEL"
        ]
        app.launch()

        let searchField = app.textFields["quickPasteSearchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5), "快速粘贴面板应出现并包含搜索框")
    }

    // MARK: - TC-F1.9-3-01 无权限时面板显示在屏幕中央

    func testPanelPositionedAtScreenCenter_WhenNoLastPosition()
    {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_QUICK_PASTE_PANEL"
        ]
        app.launch()

        let searchField = app.textFields["quickPasteSearchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))

        // 验证面板显示在屏幕中央（通过面板窗口 frame 与主屏 frame 比对，允许 ±50px 误差）
        // 注意：本测试文件顶部需 `import AppKit` 以使用 NSScreen
        let panelFrame = app.windows.containing(.textField, identifier: "quickPasteSearchField").firstMatch.frame
        let screenFrame = NSScreen.main?.frame ?? .zero
        XCTAssertEqual(panelFrame.midX, screenFrame.midX, accuracy: 50, "面板应显示在屏幕中央水平位置")
        XCTAssertEqual(panelFrame.midY, screenFrame.midY, accuracy: 50, "面板应显示在屏幕中央垂直位置")
    }

    // MARK: - TC-F1.9-8-01 Esc 键关闭面板不粘贴

    func testPanelCloses_OnEscKey()
    {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_QUICK_PASTE_PANEL"
        ]
        app.launch()

        let searchField = app.textFields["quickPasteSearchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))

        searchField.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])

        XCTAssertFalse(searchField.exists, "按 Esc 后面板应关闭")
    }

    // MARK: - TC-F1.9-9-01 面板失焦自动关闭

    func testPanelCloses_OnResignFocus()
    {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_QUICK_PASTE_PANEL"
        ]
        app.launch()

        let searchField = app.textFields["quickPasteSearchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))

        // 点击主窗口（使面板失焦）
        let mainWindow = app.windows.firstMatch
        mainWindow.click()

        // 等待面板关闭（失焦通知异步触发）
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == NO"),
            object: searchField
        )
        wait(for: [expectation], timeout: 3.0)
    }

    // MARK: - TC-F1.9-4-03 面板出现时默认高亮第一行

    func testFirstRowHighlighted_ByDefault()
    {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_PREPOPULATE_SAMPLE_AND_REAL",
            "--UITEST_QUICK_PASTE_PANEL"
        ]
        app.launch()

        // 默认高亮第一行：通过 accessibilityIdentifier 后缀 _selected 验证（未选中行无后缀）
        let firstRowSelected = app.descendants(matching: .any)["quickPasteRow_0_selected"].firstMatch
        XCTAssertTrue(firstRowSelected.waitForExistence(timeout: 5), "第一行应默认高亮选中")
    }

    // MARK: - TC-F1.9-4-01 单击列表行高亮选中

    func testSingleClick_OnSecondRow_HighlightsSecondRow()
    {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_PREPOPULATE_SAMPLE_AND_REAL",
            "--UITEST_QUICK_PASTE_PANEL"
        ]
        app.launch()

        // 单击前：第一行高亮（quickPasteRow_0_selected），第二行未高亮（quickPasteRow_1）
        let row0Selected = app.descendants(matching: .any)["quickPasteRow_0_selected"].firstMatch
        let row1Selected = app.descendants(matching: .any)["quickPasteRow_1_selected"].firstMatch
        XCTAssertTrue(row0Selected.waitForExistence(timeout: 5), "初始第一行应高亮")
        XCTAssertFalse(row1Selected.exists, "初始第二行不应高亮")

        // 单击第二行（未高亮状态的 identifier）
        let row1 = app.descendants(matching: .any)["quickPasteRow_1"].firstMatch
        XCTAssertTrue(row1.waitForExistence(timeout: 2), "第二行应存在")
        row1.click()

        // 单击后：第二行高亮，第一行取消高亮
        XCTAssertTrue(row1Selected.waitForExistence(timeout: 2), "单击后第二行应高亮")
        XCTAssertFalse(
            app.descendants(matching: .any)["quickPasteRow_0_selected"].firstMatch.exists,
            "单击后第一行应取消高亮"
        )
    }

    // MARK: - TC-F1.9-4-02 方向键上下移动高亮

    func testArrowKeys_MoveHighlightDownAndUp()
    {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_PREPOPULATE_SAMPLE_AND_REAL",
            "--UITEST_QUICK_PASTE_PANEL"
        ]
        app.launch()

        let searchField = app.textFields["quickPasteSearchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.click()

        // 初始：第一行高亮（quickPasteRow_0_selected）
        XCTAssertTrue(
            app.descendants(matching: .any)["quickPasteRow_0_selected"].firstMatch.exists,
            "初始第一行应高亮"
        )

        // 按下方向键 3 次（移到第四行，索引 3）
        searchField.typeKey(XCUIKeyboardKey.downArrow, modifierFlags: [])
        searchField.typeKey(XCUIKeyboardKey.downArrow, modifierFlags: [])
        searchField.typeKey(XCUIKeyboardKey.downArrow, modifierFlags: [])

        // 验证：第四行高亮（索引 3）
        XCTAssertTrue(
            app.descendants(matching: .any)["quickPasteRow_3_selected"].firstMatch.waitForExistence(timeout: 2),
            "按 3 次下方向键后第四行应高亮"
        )

        // 按上方向键 1 次（回到第三行，索引 2）
        searchField.typeKey(XCUIKeyboardKey.upArrow, modifierFlags: [])

        // 验证：第三行高亮（索引 2）
        XCTAssertTrue(
            app.descendants(matching: .any)["quickPasteRow_2_selected"].firstMatch.waitForExistence(timeout: 2),
            "按 1 次上方向键后第三行应高亮"
        )

        // 验证面板仍然存在（方向键不应关闭面板）
        XCTAssertTrue(searchField.exists, "方向键不应关闭面板")
    }

    // MARK: - TC-F1.9-5-01 双击文本行触发粘贴流程

    func testDoubleClick_OnTextRow_TriggersPaste()
    {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_PREPOPULATE_SAMPLE_AND_REAL",
            "--UITEST_QUICK_PASTE_PANEL"
        ]
        app.launch()

        // 第一行默认高亮（identifier 带 _selected 后缀），读取其 clip.id（accessibilityValue）
        let firstRow = app.descendants(matching: .any)["quickPasteRow_0_selected"].firstMatch
        XCTAssertTrue(firstRow.waitForExistence(timeout: 5), "第一行应存在")
        let firstClipId = firstRow.value as? String

        firstRow.doubleClick()

        // Phase 2 验证回调触发；面板关闭与真实粘贴在 Phase 3/4 验证
        // test hook：双击触发 onPasteTriggered 后，viewModel.lastTriggeredClipIdForTesting 更新，
        // 通过测试元素 quickPasteTestTriggeredClipId 暴露触发的 clip.id
        let triggeredClipIdElement = app.descendants(matching: .any)["quickPasteTestTriggeredClipId"].firstMatch
        XCTAssertTrue(triggeredClipIdElement.waitForExistence(timeout: 2), "双击应触发粘贴回调")
        XCTAssertEqual(
            triggeredClipIdElement.value as? String,
            firstClipId,
            "双击应触发粘贴回调并传入正确 ClipItem"
        )
    }

    // MARK: - TC-F1.9-5-02 回车键触发粘贴流程

    func testEnterKey_TriggersPaste()
    {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_PREPOPULATE_SAMPLE_AND_REAL",
            "--UITEST_QUICK_PASTE_PANEL"
        ]
        app.launch()

        // 默认高亮第一行，读取其 clip.id（accessibilityValue）
        let firstRow = app.descendants(matching: .any)["quickPasteRow_0_selected"].firstMatch
        XCTAssertTrue(firstRow.waitForExistence(timeout: 5), "第一行应存在")
        let firstClipId = firstRow.value as? String

        let searchField = app.textFields["quickPasteSearchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.click()

        // 按回车键
        searchField.typeKey(XCUIKeyboardKey.return, modifierFlags: [])

        // Phase 2 验证回调触发；面板关闭与真实粘贴在 Phase 3/4 验证
        // test hook：回车触发 onPasteTriggered 后，通过测试元素 quickPasteTestTriggeredClipId 暴露触发的 clip.id
        let triggeredClipIdElement = app.descendants(matching: .any)["quickPasteTestTriggeredClipId"].firstMatch
        XCTAssertTrue(triggeredClipIdElement.waitForExistence(timeout: 2), "回车应触发粘贴回调")
        XCTAssertEqual(
            triggeredClipIdElement.value as? String,
            firstClipId,
            "回车应触发粘贴回调并传入正确 ClipItem"
        )
    }

    // MARK: - TC-F1.9-11-01 双击图片类型行显示提示

    func testDoubleClick_OnImageRow_ShowsTextOnlyHint()
    {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_PREPOPULATE_IMAGE_AND_FILEPATH",  // 新启动参数：预置图片+文件路径
            "--UITEST_QUICK_PASTE_PANEL"
        ]
        app.launch()

        // 找到图片行（通过 accessibilityIdentifier 后缀或类型标签）
        let imageRow = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier CONTAINS 'quickPasteRow'")
        ).firstMatch
        XCTAssertTrue(imageRow.waitForExistence(timeout: 5))

        imageRow.doubleClick()

        let hint = app.staticTexts["textOnlyHint"].firstMatch
        XCTAssertTrue(hint.waitForExistence(timeout: 2), "应显示'仅支持文本粘贴'提示")

        // 验证面板未关闭
        let searchField = app.textFields["quickPasteSearchField"]
        XCTAssertTrue(searchField.exists, "双击图片行不应关闭面板")
    }

    // MARK: - TC-F1.9-11-03 提示后可继续操作其他行

    func testHint_ClearsOnClickOtherRow()
    {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_PREPOPULATE_IMAGE_AND_FILEPATH",
            "--UITEST_QUICK_PASTE_PANEL"
        ]
        app.launch()

        let rows = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier CONTAINS 'quickPasteRow'")
        )
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 5))

        // 双击第一行（图片）显示提示
        rows.firstMatch.doubleClick()
        let hint = app.staticTexts["textOnlyHint"].firstMatch
        XCTAssertTrue(hint.waitForExistence(timeout: 2))

        // 单击第二行
        let secondRow = rows.element(boundBy: 1)
        if secondRow.exists
        {
            secondRow.click()
            let hintCleared = NSPredicate(format: "exists == NO")
            let expectation = XCTNSPredicateExpectation(
                predicate: hintCleared,
                object: hint
            )
            wait(for: [expectation], timeout: 2.0)
        }
    }
}
