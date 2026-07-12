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
}
