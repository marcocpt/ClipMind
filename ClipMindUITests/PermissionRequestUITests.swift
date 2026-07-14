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
        cleanUpDatabase()
    }

    override func tearDown() {
        XCUIApplication().terminate()
        super.tearDown()
    }

    /// 清除上一轮测试残留的数据库文件（避免 F1.8 示例数据干扰）。
    private func cleanUpDatabase() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        let dbPath = appSupport.appendingPathComponent("ClipMind/clipmind.db")
        for suffix in ["", "-wal", "-shm"] {
            try? FileManager.default.removeItem(atPath: dbPath.path + suffix)
        }
    }

    /// 启动带引导重置参数的 App，确保进入 onboarding 流程
    private func launchFreshApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_RESET_ONBOARDING",
            "--UITEST_RESET_SETTINGS"
        ]
        app.launch()
        let window = app.windows.firstMatch
        _ = window.waitForExistence(timeout: 10)
        app.activate()
        return app
    }

    /// 查找按钮元素
    ///
    /// macOS SwiftUI 中按钮的 accessibilityIdentifier 可能不被 XCUItest 正确暴露，
    /// 优先按 label 文本查找（更可靠），回退按 identifier 查找。
    private func findButton(_ app: XCUIApplication, identifier: String) -> XCUIElement {
        let labelMap: [String: String] = [
            "startButton": "开始使用",
            "openSettingsButton": "打开系统设置"
        ]
        if let label = labelMap[identifier] {
            let byLabel = app.buttons[label]
            if byLabel.waitForExistence(timeout: 1) { return byLabel }
            let byLabelDesc = app.descendants(matching: .button)[label]
            if byLabelDesc.waitForExistence(timeout: 1) { return byLabelDesc }
        }
        return app.descendants(matching: .button)[identifier]
    }

    /// 测试点击「打开系统设置」按钮后 app 不崩溃
    ///
    /// 步骤：启动 → 进入引导 → 点击「开始使用」→ 进入权限设置 → 点击「打开系统设置」→ 验证 app 仍存活
    func testOpenAccessibilitySettingsDoesNotCrashApp() {
        let app = launchFreshApp()

        // 欢迎页：点击「开始使用」进入权限设置步骤
        let startButton = findButton(app, identifier: "startButton")
        XCTAssertTrue(
            startButton.waitForExistence(timeout: 20),
            "欢迎页的'开始使用'按钮应出现"
        )
        startButton.click()

        // 权限请求页：等待「打开系统设置」按钮出现
        let openSettingsButton = findButton(app, identifier: "openSettingsButton")
        XCTAssertTrue(
            openSettingsButton.waitForExistence(timeout: 5),
            "权限请求页的'打开系统设置'按钮应出现"
        )

        // 点击「打开系统设置」按钮
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
