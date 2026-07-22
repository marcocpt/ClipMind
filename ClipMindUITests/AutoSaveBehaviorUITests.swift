import XCTest

final class AutoSaveBehaviorUITests: XCTestCase
{
    override func setUp()
    {
        super.setUp()
        continueAfterFailure = false
    }

    // MARK: - AC-09：保存目录异常时弹窗提示不崩溃

    /// 验证保存目录配置为不存在路径时，App 不崩溃且显示错误弹窗。
    func testAC09DirectoryExceptionShowsAlertNoCrash()
    {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_RESET_AUTOSAVE_SETTINGS",
            "--UITEST_INITIAL_TAB=autosave"
        ]
        app.launch()
        app.activate()

        // 打开设置面板
        let settingsButton = app.buttons["settingsButton"].firstMatch
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.click()

        // 开启总开关
        let enabledToggle = app.checkBoxes["autoSaveEnabledToggle"]
        XCTAssertTrue(enabledToggle.waitForExistence(timeout: 5))
        if enabledToggle.value as? String == "0"
        {
            enabledToggle.click()
        }

        // 设置保存目录为不存在路径
        let directoryField = app.textFields["saveDirectoryField"]
        XCTAssertTrue(directoryField.waitForExistence(timeout: 3))
        directoryField.click()
        // 全选并删除现有内容
        directoryField.typeKey("a", modifierFlags: .command)
        directoryField.typeKey(XCUIKeyboardKey.delete, modifierFlags: [])
        directoryField.typeText("/nonexistent/path/")

        // 关闭设置窗口（Cmd+W）
        app.typeKey("w", modifierFlags: .command)

        // App 不应崩溃
        XCTAssertTrue(app.waitForExistence(timeout: 3), "App 不应崩溃")

        // 验证错误弹窗出现（autoSaveErrorAlert accessibility identifier）
        // 弹窗由 AutoSaveService 在目录异常时触发
        let errorAlert = app.alerts["autoSaveErrorAlert"]
        XCTAssertTrue(
            errorAlert.waitForExistence(timeout: 10),
            "保存目录异常时应显示错误弹窗"
        )

        // 点击确定关闭弹窗
        let okButton = errorAlert.buttons["确定"]
        if okButton.exists
        {
            okButton.click()
        }
    }

    // MARK: - AC-08：禁用总开关不触发保存（UI 烟雾测试）

    /// 验证总开关关闭时配置面板状态正确。
    func testAC08DisabledToggleNoSave()
    {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_RESET_AUTOSAVE_SETTINGS",
            "--UITEST_INITIAL_TAB=autosave"
        ]
        app.launch()
        app.activate()

        let settingsButton = app.buttons["settingsButton"].firstMatch
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.click()

        let enabledToggle = app.checkBoxes["autoSaveEnabledToggle"]
        XCTAssertTrue(enabledToggle.waitForExistence(timeout: 5))
        XCTAssertEqual(
            enabledToggle.value as? String,
            "0",
            "D11：总开关默认应关闭"
        )

        // App 不崩溃
        XCTAssertTrue(app.waitForExistence(timeout: 3), "App 不应崩溃")
    }
}
