import XCTest

/// 权限请求页面 UI 测试
///
/// 覆盖：点击「打开系统设置」按钮后 app 不崩溃。
///
/// 回归保护：早期版本 `PermissionRequester.axTrustedCheck` 默认闭包使用
/// `kAXTrustedCheckOptionPrompt` 全局 CFString 常量作为 NSDictionary 字面量 key，
/// 在 Hardened Runtime + 签名 app 上下文中该常量可能因 dyld 加载时序问题为 NULL，
/// 导致 `AXIsProcessTrustedWithOptions` 内部 `CFGetTypeID(nil)` 解引用偏移 0x8 崩溃。
/// 修复后改用字符串字面量 `"AXTrustedCheckOptionPrompt"`。
final class PermissionRequestUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// 启动参数：重置 onboarding 状态，确保进入引导流程
    private var launchArguments: [String] {
        ["--UITEST_RESET_ONBOARDING"]
    }

    /// 通过 accessibility identifier 查找元素。
    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    /// 测试点击「打开系统设置」按钮后 app 不崩溃
    ///
    /// 步骤：启动 → 进入引导 → 点击「开始使用」→ 进入权限设置 → 点击「打开系统设置」→ 验证 app 仍存活
    func testOpenAccessibilitySettingsDoesNotCrashApp() {
        let app = XCUIApplication()
        app.launchArguments = launchArguments
        app.launch()

        // 等待引导视图出现
        let onboardingView = element("onboardingView", in: app)
        XCTAssertTrue(onboardingView.waitForExistence(timeout: 5), "引导视图应出现")

        // 点击「开始使用」按钮进入权限设置步骤
        let startButton = app.buttons["startButton"].firstMatch
        XCTAssertTrue(startButton.waitForExistence(timeout: 3), "开始使用按钮应存在")
        startButton.click()

        // 等待权限请求视图出现
        let permissionView = element("permissionRequestView", in: app)
        XCTAssertTrue(permissionView.waitForExistence(timeout: 3), "权限请求视图应出现")

        // 点击辅助功能权限行内的「打开系统设置」按钮
        let accessibilityRow = element("accessibilityPermission", in: app)
        XCTAssertTrue(accessibilityRow.waitForExistence(timeout: 3), "辅助功能权限行应存在")
        let openSettingsButton = accessibilityRow.buttons.firstMatch
        XCTAssertTrue(openSettingsButton.waitForExistence(timeout: 3), "打开系统设置按钮应存在")
        openSettingsButton.click()

        // 验证 app 仍存活（不崩溃）
        // 若 AXIsProcessTrustedWithOptions 因 kAXTrustedCheckOptionPrompt 为 NULL 崩溃，
        // app 会立即退出，state 变为 .notRunning
        XCTAssertNotEqual(
            app.state,
            .notRunning,
            "点击「打开系统设置」后 app 不应崩溃退出"
        )
    }
}
