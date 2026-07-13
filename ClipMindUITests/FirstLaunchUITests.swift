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

        // 欢迎页 → 权限请求页
        XCTAssertTrue(app.otherElements["onboardingView"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.otherElements["welcomeView"].waitForExistence(timeout: 3))
        app.buttons["startButton"].click()
        XCTAssertTrue(
            app.otherElements["permissionRequestView"].waitForExistence(timeout: 3),
            "权限请求页应出现"
        )

        // 权限请求 → API Key 引导页
        app.buttons["nextButton"].click()
        XCTAssertTrue(
            app.otherElements["apiKeyGuideView"].waitForExistence(timeout: 3),
            "API Key 引导页应出现"
        )

        // API Key 引导 → 隐私提示页（跳过）
        app.buttons["skipButton"].click()
        dismissAlertIfExists(in: app)
        XCTAssertTrue(
            app.otherElements["privacyNoticeView"].waitForExistence(timeout: 3),
            "隐私提示页应出现"
        )

        // 隐私提示 → 主界面
        app.buttons["finishButton"].click()
        XCTAssertTrue(
            app.staticTexts["暂无剪贴历史"].waitForExistence(timeout: 5),
            "引导完成后应进入主界面"
        )
    }

    // MARK: - TC-24-02 API Key 配置引导可跳过

    /// 验证 API Key 配置引导页可跳过
    func testAPIKeyGuideCanBeSkipped() {
        let app = launchFreshApp()

        // 快速导航到 API Key 引导页
        XCTAssertTrue(app.buttons["startButton"].waitForExistence(timeout: 5))
        app.buttons["startButton"].click()
        XCTAssertTrue(app.buttons["nextButton"].waitForExistence(timeout: 3))
        app.buttons["nextButton"].click()
        XCTAssertTrue(
            app.otherElements["apiKeyGuideView"].waitForExistence(timeout: 3),
            "API Key 引导页应出现"
        )

        // 点击跳过
        app.buttons["skipButton"].click()
        dismissAlertIfExists(in: app)

        XCTAssertTrue(
            app.otherElements["privacyNoticeView"].waitForExistence(timeout: 3),
            "跳过 API Key 配置后应进入隐私提示页"
        )
    }

    // MARK: - 辅助方法

    /// 启动带引导重置参数的 App
    private func launchFreshApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_RESET_ONBOARDING",
            "--UITEST_SHOW_MAIN_WINDOW"
        ]
        app.launch()
        app.activate()
        return app
    }

    /// 如有弹窗则关闭
    private func dismissAlertIfExists(in app: XCUIApplication) {
        let confirm = app.buttons["确定"]
        if confirm.waitForExistence(timeout: 2) { confirm.click() }
    }
}
