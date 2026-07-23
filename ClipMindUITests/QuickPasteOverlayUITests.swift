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

    /// 等待浮层可见性 test hook 达到指定状态。
    ///
    /// NSPanel(.nonactivatingPanel) 在 CI 中无法被 XCUITest 可靠检测，
    /// 改为检测主窗口的 `quickPasteTestOverlayVisible` 元素（label "1"=可见, "0"=不可见）。
    /// - Parameters:
    ///   - app: XCUIApplication
    ///   - visible: 期望状态（true=可见, false=不可见）
    ///   - timeout: 超时秒数
    /// - Returns: 是否在超时内达到期望状态
    private func waitOverlayState(
        _ app: XCUIApplication,
        visible: Bool,
        timeout: TimeInterval
    ) -> Bool {
        let stateElement = app.staticTexts["quickPasteTestOverlayVisible"].firstMatch
        let expectedLabel = visible ? "1" : "0"
        let predicate = NSPredicate(format: "label == %@", expectedLabel)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: stateElement)
        wait(for: [expectation], timeout: timeout)
        return stateElement.label == expectedLabel
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

    /// 浮层为 NSPanel(.nonactivatingPanel)，CI 中 XCUITest 无法可靠检测浮层本身。
    /// 改为检测主窗口的 `quickPasteTestOverlayVisible` test hook 元素（label "1"=浮层可见）。
    /// 浮层文案与不显示剪贴板原文由 `PasteOverlayControllerTests` 单元测试覆盖。
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

        XCTAssertTrue(waitOverlayState(app, visible: true, timeout: 3), "应显示降级浮层")
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

        XCTAssertTrue(waitOverlayState(app, visible: true, timeout: 3), "浮层应显示")

        // 等待超时消失（1 秒 + 余量）
        XCTAssertTrue(waitOverlayState(app, visible: false, timeout: 5), "超时后浮层应消失")
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

        XCTAssertTrue(waitOverlayState(app, visible: true, timeout: 3), "浮层应显示")

        // 等待消费模拟触发浮层消失
        XCTAssertTrue(waitOverlayState(app, visible: false, timeout: 5), "消费后浮层应消失")
    }

    // MARK: - TC-F1.9-7-04 超时配置变更为 10 秒后立即生效

    func testOverlayTimeout_ConfigChangeTakesEffectImmediately()
    {
        // 第一次：配置 10 秒超时，验证 5 秒内浮层不消失
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_PREPOPULATE_SAMPLE_AND_REAL",
            "--UITEST_QUICK_PASTE_PANEL",
            "--UITEST_FORCE_NO_PERMISSION"
        ]
        // 启动前预设 10 秒超时配置（验证配置变更立即生效）
        UserDefaults.standard.set(10.0, forKey: "F1.9.quickPaste.overlayDuration")
        app.launch()

        let firstRow = app.descendants(matching: .any)["quickPasteRow_0_selected"].firstMatch
        XCTAssertTrue(firstRow.waitForExistence(timeout: 5))
        firstRow.doubleClick()

        XCTAssertTrue(waitOverlayState(app, visible: true, timeout: 3), "浮层应显示")

        // 验证浮层在 5 秒内不消失（配置为 10 秒）
        XCTAssertFalse(
            waitOverlayState(app, visible: false, timeout: 5),
            "配置 10 秒后，5 秒内浮层应仍存在"
        )

        // 第二次：修改配置为 3 秒超时，验证 4 秒内浮层消失
        app.terminate()
        UserDefaults.standard.set(3.0, forKey: "F1.9.quickPaste.overlayDuration")

        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_PREPOPULATE_SAMPLE_AND_REAL",
            "--UITEST_QUICK_PASTE_PANEL",
            "--UITEST_FORCE_NO_PERMISSION"
        ]
        app.launch()

        let firstRow2 = app.descendants(matching: .any)["quickPasteRow_0_selected"].firstMatch
        XCTAssertTrue(firstRow2.waitForExistence(timeout: 5))
        firstRow2.doubleClick()

        XCTAssertTrue(waitOverlayState(app, visible: true, timeout: 3), "浮层应再次显示")

        // 验证浮层在 4 秒内消失（配置为 3 秒）
        XCTAssertTrue(
            waitOverlayState(app, visible: false, timeout: 4),
            "配置 3 秒后，4 秒内浮层应消失"
        )

        // 清理配置
        UserDefaults.standard.removeObject(forKey: "F1.9.quickPaste.overlayDuration")
    }

    // MARK: - TC-F1.9-12-01 权限撤销时自动降级（UI 层验证降级路径）

    func testPermissionRevoked_FallsBackToDegradedPath()
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

        // 验证无权限时走降级路径（显示浮层）
        firstRow.doubleClick()
        XCTAssertTrue(waitOverlayState(app, visible: true, timeout: 3), "无权限时应显示降级浮层")

        // 等待浮层超时消失
        XCTAssertTrue(waitOverlayState(app, visible: false, timeout: 5), "超时后浮层应消失")
    }

    // MARK: - Phase 4：有权限路径 UI 测试（仅 ClipMind-Dev Scheme 运行）

    #if CLIPMIND_DEV

    // MARK: - TC-F1.9-6-01 有权限时双击自动粘贴（剪贴板写入 + 面板关闭）

    func testPermissionGrantedPaste_WritesClipboard_ClosesPanel()
    {
        // 重置 test hook：PasteSimulator 调用标记
        UserDefaults.standard.set(false, forKey: "UITest_pasteSimulatorCalled")
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_PREPOPULATE_SAMPLE_AND_REAL",
            "--UITEST_QUICK_PASTE_PANEL",
            "--UITEST_FORCE_PERMISSION"
        ]
        app.launch()

        // 记录剪贴板初始内容
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString("__INITIAL__", forType: .string)
        let initialCount = pasteboard.changeCount

        let firstRow = app.descendants(matching: .any)["quickPasteRow_0_selected"].firstMatch
        XCTAssertTrue(firstRow.waitForExistence(timeout: 5))

        firstRow.doubleClick()

        // 验证剪贴板已写入（changeCount 增加）
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "changeCount > \(initialCount)"),
            object: pasteboard
        )
        wait(for: [expectation], timeout: 3.0)

        let clipboardContent = pasteboard.string(forType: .string)
        XCTAssertNotNil(clipboardContent, "剪贴板应已写入")
        XCTAssertNotEqual(clipboardContent, "__INITIAL__", "剪贴板应已写入新内容")

        // 验证面板已关闭（quickPasteRow 不再存在）
        let panelClosedExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == NO"),
            object: firstRow
        )
        wait(for: [panelClosedExpectation], timeout: 3.0)
        XCTAssertFalse(firstRow.exists, "有权限粘贴后面板应关闭")

        // test hook：PasteSimulator.simulatePaste() 在 --UITEST_QUICK_PASTE_PANEL 启动参数下
        // 写入 UserDefaults["UITest_pasteSimulatorCalled"]，UI 测试读取验证
        let pasteSimulatorCalled = UserDefaults.standard.bool(forKey: "UITest_pasteSimulatorCalled")
        XCTAssertTrue(pasteSimulatorCalled, "应调用 PasteSimulator 模拟粘贴")

        app.terminate()
    }

    // MARK: - TC-F1.9-10-01 粘贴后面板自动关闭（有权限路径）

    func testPermissionGrantedPaste_PanelClosesAfterPaste()
    {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_PREPOPULATE_SAMPLE_AND_REAL",
            "--UITEST_QUICK_PASTE_PANEL",
            "--UITEST_FORCE_PERMISSION"
        ]
        app.launch()

        let firstRow = app.descendants(matching: .any)["quickPasteRow_0_selected"].firstMatch
        XCTAssertTrue(firstRow.waitForExistence(timeout: 5))

        firstRow.doubleClick()

        // 验证面板关闭（quickPasteRow 消失）
        let panelClosedExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == NO"),
            object: firstRow
        )
        wait(for: [panelClosedExpectation], timeout: 3.0)
        XCTAssertFalse(firstRow.exists, "有权限路径粘贴后面板应自动关闭")

        // 验证降级浮层未显示（有权限路径不显示浮层）
        let overlayMessage = app.descendants(matching: .any)["pasteOverlayMessage"].firstMatch
        XCTAssertFalse(overlayMessage.exists, "有权限路径不应显示降级浮层")

        app.terminate()
    }

    // MARK: - TC-F1.9-12-01 权限撤销时自动降级（UI 层验证降级路径切换）

    func testPermissionRevoked_FallsBackFromSimulateToOverlay()
    {
        // 第一次：有权限（模拟粘贴，不显示浮层）
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_PREPOPULATE_SAMPLE_AND_REAL",
            "--UITEST_QUICK_PASTE_PANEL",
            "--UITEST_FORCE_PERMISSION"
        ]
        app.launch()

        let firstRow = app.descendants(matching: .any)["quickPasteRow_0_selected"].firstMatch
        XCTAssertTrue(firstRow.waitForExistence(timeout: 5))
        firstRow.doubleClick()

        // 验证有权限路径：面板关闭 + 无浮层
        let panelClosedExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == NO"),
            object: firstRow
        )
        wait(for: [panelClosedExpectation], timeout: 3.0)

        let overlayMessage = app.descendants(matching: .any)["pasteOverlayMessage"].firstMatch
        XCTAssertFalse(overlayMessage.exists, "有权限路径不应显示浮层")

        app.terminate()

        // 第二次：无权限（降级路径，显示浮层）
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_PREPOPULATE_SAMPLE_AND_REAL",
            "--UITEST_QUICK_PASTE_PANEL",
            "--UITEST_FORCE_NO_PERMISSION",
            "--UITEST_OVERLAY_TIMEOUT_1S"
        ]
        app.launch()

        let firstRow2 = app.descendants(matching: .any)["quickPasteRow_0_selected"].firstMatch
        XCTAssertTrue(firstRow2.waitForExistence(timeout: 5))
        firstRow2.doubleClick()

        let overlayMessage2 = app.descendants(matching: .any)["pasteOverlayMessage"].firstMatch
        XCTAssertTrue(overlayMessage2.waitForExistence(timeout: 3), "无权限时应显示降级浮层")

        // 等待浮层超时消失
        let disappearExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == NO"),
            object: overlayMessage2
        )
        wait(for: [disappearExpectation], timeout: 5.0)

        app.terminate()
    }

    // MARK: - TC-F1.9-2-01/02 caret 定位（XCUITest 仅验证面板出现，真实 caret 定位手动验证）

    func testCaretLocation_PanelAppears_WithPermission()
    {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_PREPOPULATE_SAMPLE_AND_REAL",
            "--UITEST_QUICK_PASTE_PANEL",
            "--UITEST_FORCE_PERMISSION"
        ]
        app.launch()

        // 验证面板出现
        let firstRow = app.descendants(matching: .any)["quickPasteRow_0_selected"].firstMatch
        XCTAssertTrue(firstRow.waitForExistence(timeout: 5), "有权限时面板应出现（caret 定位或鼠标位置降级）")

        app.terminate()
    }

    #endif
}
