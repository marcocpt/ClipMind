import XCTest

final class AutoSaveSettingsUITests: XCTestCase
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

    // MARK: - AC-07：配置面板可修改全部配置项

    /// 验证自动保存配置面板所有控件存在且可交互。
    func testAC07AllConfigControlsExist()
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

        // 验证总开关存在
        let enabledToggle = element("autoSaveEnabledToggle", in: app)
        XCTAssertTrue(enabledToggle.waitForExistence(timeout: 5), "总开关应存在")

        // 验证保存目录输入框存在
        let directoryField = app.textFields["saveDirectoryField"]
        XCTAssertTrue(directoryField.waitForExistence(timeout: 3), "保存目录输入框应存在")

        // 验证文件格式选择器存在
        let formatPicker = app.popUpButtons["fileFormatPicker"]
        XCTAssertTrue(formatPicker.waitForExistence(timeout: 3), "文件格式选择器应存在")

        // 决策 C1：长度阈值/文件名长度改为 TextField（替换原 Stepper）
        let lengthThresholdField = app.textFields["lengthThresholdField"]
        XCTAssertTrue(lengthThresholdField.waitForExistence(timeout: 3), "长度阈值 TextField 应存在")

        let fileNameLengthField = app.textFields["fileNameLengthField"]
        XCTAssertTrue(fileNameLengthField.waitForExistence(timeout: 3), "文件名长度 TextField 应存在")

        // 验证路径格式选择器存在
        let pathPicker = app.popUpButtons["pathFormatPicker"]
        XCTAssertTrue(pathPicker.waitForExistence(timeout: 3), "路径格式选择器应存在")

        // 验证敏感过滤开关存在
        let sensitiveToggle = element("sensitiveFilterToggle", in: app)
        XCTAssertTrue(sensitiveToggle.waitForExistence(timeout: 3), "敏感过滤开关应存在")

        // 验证路径预览存在
        let pathPreview = app.staticTexts["pathPreviewText"]
        XCTAssertTrue(pathPreview.waitForExistence(timeout: 3), "路径预览应存在")

        // 验证明文责任提示存在
        let warning = app.staticTexts["responsibilityWarning"]
        XCTAssertTrue(warning.waitForExistence(timeout: 3), "明文责任提示应存在")
    }

    // MARK: - AC-15：白名单 App 管理可添加与删除

    /// 验证白名单添加与删除 UI 交互。
    func testAC15WhitelistAddAndDelete()
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

        // 添加白名单条目
        let addField = app.textFields["whitelistAddField"]
        XCTAssertTrue(addField.waitForExistence(timeout: 5))
        addField.click()
        addField.typeText("com.test.whitelist")

        let addButton = app.buttons["whitelistAddButton"]
        XCTAssertTrue(addButton.exists)
        addButton.click()

        // 验证新条目出现
        let deleteButton = app.buttons["whitelistDelete_com.test.whitelist"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 3), "新增白名单条目应出现")

        // 删除条目
        deleteButton.click()
        XCTAssertFalse(deleteButton.waitForExistence(timeout: 2), "删除后条目应消失")
    }

    // MARK: - AC-16：配置修改持久化

    /// 验证总开关切换后重启 App 仍保留。
    func testAC16ConfigPersistsAcrossRestart()
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

        // 开启总开关
        let enabledToggle = element("autoSaveEnabledToggle", in: app)
        XCTAssertTrue(enabledToggle.waitForExistence(timeout: 5))
        if toggleValue(enabledToggle) == 0
        {
            enabledToggle.click()
        }
        XCTAssertEqual(toggleValue(enabledToggle), 1, "总开关应已开启")

        // 重启 App
        app.terminate()

        let app2 = XCUIApplication()
        app2.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_INITIAL_TAB=autosave"
        ]
        app2.launch()
        app2.activate()

        let settingsButton2 = app2.buttons["settingsButton"].firstMatch
        XCTAssertTrue(settingsButton2.waitForExistence(timeout: 5))
        settingsButton2.click()

        let enabledToggle2 = element("autoSaveEnabledToggle", in: app2)
        XCTAssertTrue(enabledToggle2.waitForExistence(timeout: 5))
        XCTAssertEqual(toggleValue(enabledToggle2), 1, "总开关状态应持久化保留")
    }

    // MARK: - AC-14：关闭敏感过滤二次确认 UI

    /// 验证关闭敏感过滤时弹出二次确认弹窗。
    func testAC14DisableSensitiveShowsConfirmDialog()
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

        // 敏感过滤默认开启，点击关闭
        let sensitiveToggle = element("sensitiveFilterToggle", in: app)
        XCTAssertTrue(sensitiveToggle.waitForExistence(timeout: 5))
        XCTAssertEqual(toggleValue(sensitiveToggle), 1, "敏感过滤应默认开启")
        sensitiveToggle.click()

        // 验证二次确认弹窗出现
        let cancelButton = app.buttons["取消"].firstMatch
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 3), "二次确认弹窗应出现")

        // 点击取消，开关应恢复为开启
        cancelButton.click()
        let sensitiveToggleAfter = element("sensitiveFilterToggle", in: app)
        XCTAssertEqual(toggleValue(sensitiveToggleAfter), 1, "取消后敏感过滤应恢复开启")
    }
}
