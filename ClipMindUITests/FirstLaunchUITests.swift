import XCTest

/// 首次启动引导流程 UI 测试（AC-24）
final class FirstLaunchUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        cleanUpDatabase()
    }

    override func tearDown() {
        XCUIApplication().terminate()
        super.tearDown()
    }

    /// 清除上一轮测试残留的数据库文件（F1.8 示例数据注入后需清理）。
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

        // 引导完成后应进入主界面（F1.8 后示例数据注入较快，historyList 也算主界面已出现）
        XCTAssertTrue(
            app.staticTexts["暂无剪贴历史"].waitForExistence(timeout: 3)
                || app.staticTexts["复制任何内容，它将自动出现在这里"].waitForExistence(timeout: 3)
                || app.descendants(matching: .any)["historyList"].firstMatch.waitForExistence(timeout: 5),
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

    /// 查找按钮元素
    ///
    /// macOS SwiftUI 中按钮的 accessibilityIdentifier 可能不被 XCUItest 正确暴露，
    /// 优先按 label 查找（更可靠），回退按 identifier 查找。
    private func findButton(_ app: XCUIApplication, identifier: String) -> XCUIElement {
        let labelMap: [String: String] = [
            "startButton": "开始使用",
            "nextButton": "下一步",
            "skipButton": "跳过",
            "finishButton": "开始使用 ClipMind",
            "backButton": "上一步"
        ]
        // 优先按 label 文本查找（macOS XCUItest 更可靠）
        if let label = labelMap[identifier] {
            let byLabel = app.buttons[label]
            if byLabel.waitForExistence(timeout: 1) { return byLabel }
            let byLabelDesc = app.descendants(matching: .button)[label]
            if byLabelDesc.waitForExistence(timeout: 1) { return byLabelDesc }
        }
        // 回退按 identifier 查找
        return app.descendants(matching: .button)[identifier]
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
        // 在 alert sheet 中查找确定按钮，避免匹配到 Touch Bar 元素
        let confirm = app.sheets.buttons["确定"].firstMatch
        if confirm.waitForExistence(timeout: 2) { confirm.click() }
    }
}
