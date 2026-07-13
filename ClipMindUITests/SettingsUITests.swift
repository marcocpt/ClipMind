import XCTest

final class SettingsUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// 通过 accessibility identifier 查找元素。
    ///
    /// Label/Image 等 SwiftUI 组件在 macOS XCUITest 中可能映射为 staticText、
    /// image 或 otherElements，使用 descendants(.any) 兜底（参考 PopoverUITests 模式）。
    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    // MARK: - UI-AC-15: 设置面板入口

    /// SwiftUI toolbar Button 在 macOS XCUITest 中存在嵌套结构（Toolbar→Button→Button），
    /// 同一 accessibilityIdentifier 会被识别为多个匹配。统一用 firstMatch 取最外层。
    private func settingsButton(in app: XCUIApplication) -> XCUIElement {
        app.buttons["settingsButton"].firstMatch
    }

    func testSettingsButtonExists() {
        let app = XCUIApplication()
        app.launchArguments = ["--UITEST_SHOW_MAIN_WINDOW"]
        app.launch()
        app.activate()

        let settingsButton = settingsButton(in: app)
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5), "主窗口应有设置按钮")
    }

    /// 点击设置按钮后设置面板应打开。
    ///
    /// 注意：macOS 13 的 SwiftUI Settings 场景中，`.tabItem` 内 Label 的
    /// accessibilityIdentifier 不会被保留到工具栏 tab 按钮上，
    /// 因此通过检查 APIKeyConfigView 内部的 providerPicker 来验证面板已打开。
    func testSettingsPanelOpens() {
        let app = XCUIApplication()
        app.launchArguments = ["--UITEST_SHOW_MAIN_WINDOW"]
        app.launch()
        app.activate()

        let settingsButton = settingsButton(in: app)
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.click()

        let providerPicker = app.popUpButtons["providerPicker"]
        XCTAssertTrue(
            providerPicker.waitForExistence(timeout: 5),
            "设置面板应打开并显示 API Key 配置视图"
        )
    }

    // MARK: - UI-AC-16: API Key 配置组件

    func testAPIKeyConfigComponentsExist() {
        let app = XCUIApplication()
        app.launchArguments = ["--UITEST_SHOW_MAIN_WINDOW"]
        app.launch()
        app.activate()

        settingsButton(in: app).click()

        XCTAssertTrue(
            app.popUpButtons["providerPicker"].waitForExistence(timeout: 5),
            "应有提供商选择器"
        )
        XCTAssertTrue(
            app.secureTextFields["apiKeyInput"].waitForExistence(timeout: 5),
            "应有 API Key 输入框"
        )
        XCTAssertTrue(
            app.buttons["validateButton"].waitForExistence(timeout: 5),
            "应有验证按钮"
        )
    }

    // MARK: - 未配置状态显示

    func testUnconfiguredStatusShows() {
        let app = XCUIApplication()
        app.launchArguments = ["--UITEST_SHOW_MAIN_WINDOW", "--UITEST_NO_API_KEY"]
        app.launch()
        app.activate()

        settingsButton(in: app).click()

        let status = element("unconfiguredStatus", in: app)
        XCTAssertTrue(status.waitForExistence(timeout: 5), "未配置时应显示未配置状态")
    }

    // MARK: - 验证按钮在输入为空时禁用

    func testValidateButtonDisabledWhenInputEmpty() {
        let app = XCUIApplication()
        app.launchArguments = ["--UITEST_SHOW_MAIN_WINDOW", "--UITEST_NO_API_KEY"]
        app.launch()
        app.activate()

        settingsButton(in: app).click()

        let validateButton = app.buttons["validateButton"].firstMatch
        XCTAssertTrue(validateButton.waitForExistence(timeout: 5))
        XCTAssertFalse(validateButton.isEnabled, "输入为空时验证按钮应禁用")
    }

    // MARK: - 通用设置（T3.6）

    /// 通用设置测试统一的启动参数
    private var generalLaunchArguments: [String] {
        ["--UITEST_SHOW_MAIN_WINDOW", "--UITEST_RESET_SETTINGS", "--UITEST_INITIAL_TAB=general"]
    }

    /// 获取 Toggle 的布尔值（macOS 上 Toggle.value 为 NSNumber 1/0）
    private func toggleValue(_ toggle: XCUIElement) -> Int {
        if let intValue = toggle.value as? Int {
            return intValue
        }
        if let stringValue = toggle.value as? String {
            return Int(stringValue) ?? 0
        }
        return 0
    }

    /// 启动 App 并打开设置面板（通用标签已通过启动参数定位）
    private func launchAndOpenGeneralSettings() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = generalLaunchArguments
        app.launch()
        app.activate()

        let settingsButton = app.buttons["settingsButton"].firstMatch
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5), "设置按钮应存在")
        settingsButton.click()

        // 等待通用标签内容加载（launchAtLoginToggle 是通用页独有元素）
        let launchToggle = element("launchAtLoginToggle", in: app)
        XCTAssertTrue(
            launchToggle.waitForExistence(timeout: 5),
            "通用标签应已激活，开机启动开关应存在"
        )
        return app
    }

    /// 验证通用设置组件存在
    func testGeneralSettingsComponentsExist() {
        let app = launchAndOpenGeneralSettings()

        XCTAssertTrue(
            element("launchAtLoginToggle", in: app).exists,
            "应有开机启动开关"
        )
        XCTAssertTrue(
            element("hotkeyRecorder", in: app).exists,
            "应有快捷键录制器"
        )
    }

    /// 验证开机启动开关可切换。
    ///
    /// click 前调用 `app.activate()` 确保窗口有焦点，click 后短暂 sleep
    /// 让 @AppStorage 写入完成。本地运行受系统通知/焦点切换干扰，
    /// CI 环境更稳定。
    func testLaunchAtLoginToggleSwitches() {
        let app = launchAndOpenGeneralSettings()

        let toggle = element("launchAtLoginToggle", in: app)
        XCTAssertTrue(toggle.exists)

        let initialValue = toggleValue(toggle)

        app.activate()
        toggle.click()
        Thread.sleep(forTimeInterval: 0.5)

        let newValue = toggleValue(toggle)
        XCTAssertNotEqual(initialValue, newValue, "切换后状态应改变")

        // 再次切换验证可重复操作
        app.activate()
        toggle.click()
        Thread.sleep(forTimeInterval: 0.5)
        let backValue = toggleValue(toggle)
        XCTAssertEqual(backValue, initialValue, "再次切换应回到初始值")
    }
}
