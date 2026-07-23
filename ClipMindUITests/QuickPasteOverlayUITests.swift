import AppKit
import XCTest

/// F1.9 快捷粘贴面板降级浮层 UI 测试（Phase 3）。
///
/// 覆盖 TC-F1.9-7-04 设置面板包含浮层超时配置 Stepper。
/// 后续任务（任务 7/8）会向本文件追加更多 UI 测试。
final class QuickPasteOverlayUITests: XCTestCase
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
        // 清除浮层超时配置（避免上次配置干扰测试）
        UserDefaults.standard.removeObject(forKey: "F1.9.quickPaste.overlayDuration")
    }

    // MARK: - TC-F1.9-7-04 设置面板包含浮层超时配置 Stepper

    func testSettings_ContainsOverlayTimeoutStepper()
    {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_RESET_SETTINGS",
            "--UITEST_INITIAL_TAB=general"
        ]
        app.launch()
        app.activate()

        // 通过主窗口工具栏打开设置面板
        let settingsButton = app.buttons["settingsButton"].firstMatch
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5), "设置按钮应存在")
        settingsButton.click()

        // 等待通用标签内容加载（launchAtLoginToggle 是通用页独有元素）
        // Toggle 在 macOS XCUITest 中可能映射为多种元素类型，用 descendants(.any) 兜底
        let launchToggle = app.descendants(matching: .any)["launchAtLoginToggle"].firstMatch
        XCTAssertTrue(
            launchToggle.waitForExistence(timeout: 5),
            "通用标签应已激活，开机启动开关应存在"
        )

        let overlayStepper = app.steppers["overlayTimeoutStepper"].firstMatch
        XCTAssertTrue(
            overlayStepper.waitForExistence(timeout: 5),
            "设置面板应包含浮层超时 Stepper"
        )
    }

    // MARK: - TC-F1.9-7-01 无权限时双击降级粘贴流程

    func testDegradedPaste_ShowsOverlay_OnDoubleClick()
    {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_PREPOPULATE_SAMPLE_AND_REAL",
            "--UITEST_QUICK_PASTE_PANEL",
            "--UITEST_FORCE_NO_PERMISSION"
        ]
        app.launch()

        let firstRow = app.descendants(matching: .any)["quickPasteRow_0_selected"].firstMatch
        XCTAssertTrue(firstRow.waitForExistence(timeout: 5))

        firstRow.doubleClick()

        let overlayMessage = app.descendants(matching: .any)["pasteOverlayMessage"].firstMatch
        XCTAssertTrue(overlayMessage.waitForExistence(timeout: 3), "应显示降级浮层")
    }

    // MARK: - TC-F1.9-7-03 降级浮层在超时兜底后消失（默认 5 秒，测试用 1 秒加速）

    func testOverlay_Disappears_OnTimeout()
    {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_PREPOPULATE_SAMPLE_AND_REAL",
            "--UITEST_QUICK_PASTE_PANEL",
            "--UITEST_FORCE_NO_PERMISSION",
            "--UITEST_OVERLAY_TIMEOUT_1S"
        ]
        app.launch()

        let firstRow = app.descendants(matching: .any)["quickPasteRow_0_selected"].firstMatch
        XCTAssertTrue(firstRow.waitForExistence(timeout: 5))
        firstRow.doubleClick()

        let overlayMessage = app.descendants(matching: .any)["pasteOverlayMessage"].firstMatch
        XCTAssertTrue(overlayMessage.waitForExistence(timeout: 3), "浮层应显示")

        // 等待超时消失（1 秒 + 余量）
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == NO"),
            object: overlayMessage
        )
        wait(for: [expectation], timeout: 5.0)
        XCTAssertFalse(overlayMessage.exists, "超时后浮层应消失")
    }

    // MARK: - TC-F1.9-7-02 降级浮层在剪贴板被消费后消失

    func testOverlay_Disappears_OnClipboardConsumption()
    {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_PREPOPULATE_SAMPLE_AND_REAL",
            "--UITEST_QUICK_PASTE_PANEL",
            "--UITEST_FORCE_NO_PERMISSION",
            "--UITEST_SIMULATE_CONSUMPTION_AFTER_1S"
        ]
        app.launch()

        let firstRow = app.descendants(matching: .any)["quickPasteRow_0_selected"].firstMatch
        XCTAssertTrue(firstRow.waitForExistence(timeout: 5))
        firstRow.doubleClick()

        let overlayMessage = app.descendants(matching: .any)["pasteOverlayMessage"].firstMatch
        XCTAssertTrue(overlayMessage.waitForExistence(timeout: 3), "浮层应显示")

        // 等待消费模拟触发浮层消失
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == NO"),
            object: overlayMessage
        )
        wait(for: [expectation], timeout: 5.0)
        XCTAssertFalse(overlayMessage.exists, "消费后浮层应消失")
    }
}
