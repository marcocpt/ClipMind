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
}
