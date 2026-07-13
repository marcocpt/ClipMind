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
        XCTAssertTrue(
            app.buttons["startButton"].waitForExistence(timeout: 20),
            "欢迎页的'开始使用'按钮应出现"
        )
        app.buttons["startButton"].click()

        // 权限请求页：等待 "下一步" 按钮出现并点击
        XCTAssertTrue(
            app.buttons["nextButton"].waitForExistence(timeout: 5),
            "权限请求页的'下一步'按钮应出现"
        )
        app.buttons["nextButton"].click()

        // API Key 引导页：点击 "跳过"
        XCTAssertTrue(
            app.buttons["skipButton"].waitForExistence(timeout: 5),
            "API Key 引导页的'跳过'按钮应出现"
        )
        app.buttons["skipButton"].click()
        dismissAlertIfExists(in: app)

        // 隐私提示页：等待 "开始使用 ClipMind" 按钮出现并点击
        XCTAssertTrue(
            app.buttons["finishButton"].waitForExistence(timeout: 5),
            "隐私提示页的'开始使用 ClipMind'按钮应出现"
        )
        app.buttons["finishButton"].click()

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
        XCTAssertTrue(app.buttons["startButton"].waitForExistence(timeout: 20))
        app.buttons["startButton"].click()
        XCTAssertTrue(app.buttons["nextButton"].waitForExistence(timeout: 5))
        app.buttons["nextButton"].click()
        XCTAssertTrue(
            app.buttons["skipButton"].waitForExistence(timeout: 5),
            "API Key 引导页的'跳过'按钮应出现"
        )

        // 点击跳过
        app.buttons["skipButton"].click()
        dismissAlertIfExists(in: app)

        XCTAssertTrue(
            app.buttons["finishButton"].waitForExistence(timeout: 5),
            "跳过 API Key 配置后应进入隐私提示页"
        )
    }

    // MARK: - 辅助方法

    /// 启动带引导重置参数的 App
    ///
    /// 使用独立的 bundle identifier 来完全隔离 UserDefaults，避免其他 UI 测试的
    /// hasCompletedOnboarding=true 残留影响引导流程。
    /// 注意：不能使用 --UITEST_SHOW_MAIN_WINDOW，该参数会设置 hasCompletedOnboarding=true，
    /// 导致引导流程被跳过。
    private func launchFreshApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_RESET_ONBOARDING",
            "--UITEST_RESET_SETTINGS"
        ]
        app.launch()
        // 等待窗口出现后再激活，确保 SwiftUI WindowGroup 已完成初始化
        let window = app.windows.firstMatch
        _ = window.waitForExistence(timeout: 10)
        app.activate()
        return app
    }

    /// 如有弹窗则关闭
    private func dismissAlertIfExists(in app: XCUIApplication) {
        let confirm = app.buttons["确定"]
        if confirm.waitForExistence(timeout: 2) { confirm.click() }
    }
}
