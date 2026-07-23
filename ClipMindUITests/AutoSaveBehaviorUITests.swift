import XCTest

final class AutoSaveBehaviorUITests: XCTestCase
{
    override func setUp()
    {
        super.setUp()
        continueAfterFailure = false
    }

    /// 通过 accessibility identifier 查找元素。
    ///
    /// SwiftUI Toggle 在 macOS XCUITest 中可能映射为 switch、checkbox 或 otherElements，
    /// 使用 descendants(.any) 兜底（参考 PrivacyUITests/SettingsUITests 模式）。
    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement
    {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    /// 获取 Toggle 的布尔值（macOS 上 Toggle.value 可能为 Int 1/0 或 String "0"/"1"）。
    private func toggleValue(_ toggle: XCUIElement) -> Int
    {
        if let intValue = toggle.value as? Int
        {
            return intValue
        }
        if let stringValue = toggle.value as? String
        {
            return Int(stringValue) ?? 0
        }
        return 0
    }

    // MARK: - AC-09：保存目录异常时不崩溃

    /// 验证保存目录配置为不存在路径时，App 不崩溃。
    ///
    /// 测试策略：设置无效保存目录后，验证 App 仍在运行。
    /// 错误弹窗（NSAlert）由 AutoSaveService 写入失败时触发，但 XCUITest 中
    /// 无法可靠触发完整的剪贴板→AutoSave 流程（白名单过滤、CI 环境限制），
    /// 因此弹窗验证由单元测试覆盖，UI 测试只验证不崩溃。
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
        let enabledToggle = element("autoSaveEnabledToggle", in: app)
        XCTAssertTrue(enabledToggle.waitForExistence(timeout: 5))
        if toggleValue(enabledToggle) == 0
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

        // App 不应崩溃
        XCTAssertNotEqual(app.state, .notRunning, "App 不应崩溃")
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

        let enabledToggle = element("autoSaveEnabledToggle", in: app)
        XCTAssertTrue(enabledToggle.waitForExistence(timeout: 5))
        XCTAssertEqual(
            toggleValue(enabledToggle),
            0,
            "D11：总开关默认应关闭"
        )

        // App 不崩溃
        XCTAssertTrue(app.waitForExistence(timeout: 3), "App 不应崩溃")
    }
}
