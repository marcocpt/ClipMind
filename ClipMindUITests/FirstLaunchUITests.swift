import XCTest

/// 首次启动引导流程 UI 测试（AC-24）
final class FirstLaunchUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    // MARK: - TC-24-01 首次启动引导流程完整

    /// 验证首次启动引导流程完整步骤
    func testFirstLaunchOnboardingFlow() {
        let app = launchFreshApp()

        // 欢迎页：等待 "开始使用" 按钮出现并点击
        let startButton = findButton(app, identifier: "startButton")
        XCTAssertTrue(
            startButton.waitForExistence(timeout: 20),
            "欢迎页的'开始使用'按钮应出现"
        )
        startButton.click()

        // 权限请求页：等待 "下一步" 按钮出现并点击
        let nextButton1 = findButton(app, identifier: "nextButton")
        XCTAssertTrue(
            nextButton1.waitForExistence(timeout: 5),
            "权限请求页的'下一步'按钮应出现"
        )
        nextButton1.click()

        // API Key 引导页：点击 "跳过"
        let skipButton = findButton(app, identifier: "skipButton")
        XCTAssertTrue(
            skipButton.waitForExistence(timeout: 5),
            "API Key 引导页的'跳过'按钮应出现"
        )
        skipButton.click()
        dismissAlertIfExists(in: app)

        // 隐私提示页：等待 "开始使用 ClipMind" 按钮出现并点击
        let finishButton = findButton(app, identifier: "finishButton")
        XCTAssertTrue(
            finishButton.waitForExistence(timeout: 5),
            "隐私提示页的'开始使用 ClipMind'按钮应出现"
        )
        finishButton.click()

        // 引导完成后应进入主界面
        XCTAssertTrue(
            app.staticTexts["暂无剪贴历史"].waitForExistence(timeout: 5)
                || app.staticTexts["复制任何内容，它将自动出现在这里"].waitForExistence(timeout: 5),
            "引导完成后应进入主界面"
        )
    }

    // MARK: - TC-24-02 API Key 配置引导可跳过

    /// 验证 API Key 配置引导页可跳过
    func testAPIKeyGuideCanBeSkipped() {
        let app = launchFreshApp()

        // 快速导航到 API Key 引导页
        let startButton = findButton(app, identifier: "startButton")
        XCTAssertTrue(startButton.waitForExistence(timeout: 20))
        startButton.click()
        let nextButton = findButton(app, identifier: "nextButton")
        XCTAssertTrue(nextButton.waitForExistence(timeout: 5))
        nextButton.click()
        let skipButton = findButton(app, identifier: "skipButton")
        XCTAssertTrue(
            skipButton.waitForExistence(timeout: 5),
            "API Key 引导页的'跳过'按钮应出现"
        )

        // 点击跳过
        skipButton.click()
        dismissAlertIfExists(in: app)

        let finishButton = findButton(app, identifier: "finishButton")
        XCTAssertTrue(
            finishButton.waitForExistence(timeout: 5),
            "跳过 API Key 配置后应进入隐私提示页"
        )
    }

    // MARK: - 辅助方法

    /// 查找按钮元素，使用 descendants 在整个可访问性树中搜索
    ///
    /// macOS SwiftUI 中，按钮可能嵌套在 group 内，
    /// app.buttons[identifier] 仅搜索顶层按钮，可能找不到。
    private func findButton(_ app: XCUIApplication, identifier: String) -> XCUIElement {
        app.descendants(matching: .button)[identifier]
    }

    /// 启动带引导重置参数的 App
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

    /// 如有弹窗则关闭
    private func dismissAlertIfExists(in app: XCUIApplication) {
        let confirm = app.descendants(matching: .button)["确定"]
        if confirm.waitForExistence(timeout: 2) { confirm.click() }
    }
}
