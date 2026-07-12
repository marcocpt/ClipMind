import XCTest

/// T2.5 一键处理 UI 测试。
///
/// 覆盖验收用例：
/// - UI-AC-08: 一键处理按钮（有 Key）
/// - UI-AC-09: 一键处理按钮（无 Key）
/// - UI-AC-10: 智能总结结果展示
/// - UI-AC-11: 即时翻译结果展示
/// - UI-AC-12: 智能改写模式选择
/// - UI-AC-13: 提取待办结果展示
/// - AC-17: 未配置 API Key 时按钮置灰
final class ProcessingUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    // MARK: - 启动辅助

    /// 启动 app 并注入预览数据，自动选中第一条 clip。
    /// - Parameters:
    ///   - forceConfigured: 是否强制 API Key 已配置
    ///   - mockSummary: mock 总结结果
    ///   - mockTranslation: mock 翻译结果
    ///   - mockRewrite: mock 改写结果
    ///   - mockTodos: mock 待办 JSON 字符串
    private func launchApp(
        forceConfigured: Bool = false,
        mockSummary: String? = nil,
        mockTranslation: String? = nil,
        mockRewrite: String? = nil,
        mockTodos: String? = nil
    ) -> XCUIApplication {
        let app = XCUIApplication()
        let args = ["--UITEST_SHOW_MAIN_WINDOW", "--UITEST_PREVIEW_DATA", "--UITEST_AUTO_SELECT_FIRST"]
        app.launchArguments = args
        if forceConfigured {
            app.launchEnvironment["UITEST_FORCE_CONFIGURED"] = "1"
        }
        if let mockSummary {
            app.launchEnvironment["UITEST_MOCK_SUMMARY"] = mockSummary
        }
        if let mockTranslation {
            app.launchEnvironment["UITEST_MOCK_TRANSLATION"] = mockTranslation
        }
        if let mockRewrite {
            app.launchEnvironment["UITEST_MOCK_REWRITE"] = mockRewrite
        }
        if let mockTodos {
            app.launchEnvironment["UITEST_MOCK_TODOS"] = mockTodos
        }
        app.launch()
        app.activate()
        return app
    }

    // MARK: - TC-13-02: 处理按钮存在

    /// 验证选中 clip 后，4 个处理按钮均可见。
    func testProcessingButtonsExist() {
        let app = launchApp(forceConfigured: true)

        XCTAssertTrue(
            app.buttons["summarizeButton"].waitForExistence(timeout: 5),
            "应显示智能总结按钮"
        )
        XCTAssertTrue(
            app.buttons["translateButton"].waitForExistence(timeout: 5),
            "应显示即时翻译按钮"
        )
        XCTAssertTrue(
            app.buttons["rewriteButton"].waitForExistence(timeout: 5),
            "应显示智能改写按钮"
        )
        XCTAssertTrue(
            app.buttons["extractTodoButton"].waitForExistence(timeout: 5),
            "应显示提取待办按钮"
        )
    }

    // MARK: - AC-17 / TC-17-01: 未配置时按钮置灰

    /// 未配置 API Key 时，处理按钮应置灰（disabled）。
    func testProcessingButtonsDisabledWhenNoAPIKey() {
        let app = launchApp(forceConfigured: false)

        let summarizeButton = app.buttons["summarizeButton"]
        XCTAssertTrue(summarizeButton.waitForExistence(timeout: 5), "总结按钮应存在")
        XCTAssertFalse(summarizeButton.isEnabled, "未配置 API Key 时总结按钮应置灰")

        let translateButton = app.buttons["translateButton"]
        XCTAssertTrue(translateButton.exists, "翻译按钮应存在")
        XCTAssertFalse(translateButton.isEnabled, "未配置 API Key 时翻译按钮应置灰")

        let rewriteButton = app.buttons["rewriteButton"]
        XCTAssertTrue(rewriteButton.exists, "改写按钮应存在")
        XCTAssertFalse(rewriteButton.isEnabled, "未配置 API Key 时改写按钮应置灰")

        let extractTodoButton = app.buttons["extractTodoButton"]
        XCTAssertTrue(extractTodoButton.exists, "提取待办按钮应存在")
        XCTAssertFalse(extractTodoButton.isEnabled, "未配置 API Key 时提取待办按钮应置灰")
    }

    // MARK: - UI-AC-08: 已配置时按钮启用

    /// 已配置 API Key 时，处理按钮应启用。
    func testProcessingButtonsEnabledWhenConfigured() {
        let app = launchApp(forceConfigured: true)

        let summarizeButton = app.buttons["summarizeButton"]
        XCTAssertTrue(summarizeButton.waitForExistence(timeout: 5), "总结按钮应存在")
        XCTAssertTrue(summarizeButton.isEnabled, "已配置 API Key 时总结按钮应启用")

        let translateButton = app.buttons["translateButton"]
        XCTAssertTrue(translateButton.isEnabled, "已配置 API Key 时翻译按钮应启用")

        let rewriteButton = app.buttons["rewriteButton"]
        XCTAssertTrue(rewriteButton.isEnabled, "已配置 API Key 时改写按钮应启用")

        let extractTodoButton = app.buttons["extractTodoButton"]
        XCTAssertTrue(extractTodoButton.isEnabled, "已配置 API Key 时提取待办按钮应启用")
    }

    // MARK: - UI-AC-12: 智能改写模式选择

    /// 点击改写按钮后，应弹出 3 种模式选项。
    func testRewriteModePickerShows() {
        let app = launchApp(forceConfigured: true)

        let rewriteButton = app.buttons["rewriteButton"]
        XCTAssertTrue(rewriteButton.waitForExistence(timeout: 5), "改写按钮应存在")
        rewriteButton.click()

        let picker = app.descendants(matching: .any)["rewriteModePicker"].firstMatch
        XCTAssertTrue(
            picker.waitForExistence(timeout: 3),
            "点击改写按钮后应显示模式选择器"
        )

        XCTAssertTrue(
            app.buttons["adjustToneOption"].waitForExistence(timeout: 3),
            "应显示调整语气选项"
        )
        XCTAssertTrue(
            app.buttons["condenseOption"].exists,
            "应显示精简选项"
        )
        XCTAssertTrue(
            app.buttons["expandOption"].exists,
            "应显示扩写选项"
        )
    }

    // MARK: - UI-AC-10: 智能总结结果展示

    /// 点击总结按钮后，应显示总结结果区块（使用 mock 数据）。
    func testSummaryResultBlockDisplayed() {
        let app = launchApp(
            forceConfigured: true,
            mockSummary: "这是 mock 总结结果。包含三个要点。测试通过。"
        )

        let summarizeButton = app.buttons["summarizeButton"]
        XCTAssertTrue(summarizeButton.waitForExistence(timeout: 5), "总结按钮应存在")
        summarizeButton.click()

        let resultBlock = app.descendants(matching: .any)["summaryResultBlock"].firstMatch
        XCTAssertTrue(
            resultBlock.waitForExistence(timeout: 5),
            "点击总结按钮后应显示总结结果区块"
        )

        let summaryText = app.staticTexts["这是 mock 总结结果。包含三个要点。测试通过。"]
        XCTAssertTrue(
            summaryText.waitForExistence(timeout: 3),
            "总结结果区块应显示 mock 总结文本"
        )
    }

    // MARK: - UI-AC-11: 即时翻译结果展示

    /// 点击翻译按钮后，应显示翻译结果区块（使用 mock 数据）。
    func testTranslationResultBlockDisplayed() {
        let app = launchApp(
            forceConfigured: true,
            mockTranslation: "Hello World -> 你好世界"
        )

        let translateButton = app.buttons["translateButton"]
        XCTAssertTrue(translateButton.waitForExistence(timeout: 5), "翻译按钮应存在")
        translateButton.click()

        let resultBlock = app.descendants(matching: .any)["translationResultBlock"].firstMatch
        XCTAssertTrue(
            resultBlock.waitForExistence(timeout: 5),
            "点击翻译按钮后应显示翻译结果区块"
        )
    }

    // MARK: - UI-AC-13: 提取待办结果展示

    /// 点击提取待办按钮后，应显示待办结果区块（使用 mock 数据）。
    func testTodoResultBlockDisplayed() {
        let mockTodosJSON = """
        [{"id":"00000000-0000-0000-0000-000000000001","task":"修复登录 bug","assignee":"张三","dueDate":"周五前"}]
        """
        let app = launchApp(
            forceConfigured: true,
            mockTodos: mockTodosJSON
        )

        let extractTodoButton = app.buttons["extractTodoButton"]
        XCTAssertTrue(extractTodoButton.waitForExistence(timeout: 5), "提取待办按钮应存在")
        extractTodoButton.click()

        let resultBlock = app.descendants(matching: .any)["todoResultBlock"].firstMatch
        XCTAssertTrue(
            resultBlock.waitForExistence(timeout: 5),
            "点击提取待办按钮后应显示待办结果区块"
        )

        XCTAssertTrue(
            app.staticTexts["修复登录 bug"].waitForExistence(timeout: 3),
            "待办结果区块应显示任务内容"
        )
    }

    // MARK: - 复制结果按钮

    /// 结果区块应包含复制按钮。
    func testCopyButtonExistsInResultBlock() {
        let app = launchApp(
            forceConfigured: true,
            mockSummary: "mock 总结内容"
        )

        let summarizeButton = app.buttons["summarizeButton"]
        XCTAssertTrue(summarizeButton.waitForExistence(timeout: 5))
        summarizeButton.click()

        let copyButton = app.buttons["copySummaryButton"]
        XCTAssertTrue(
            copyButton.waitForExistence(timeout: 3),
            "总结结果区块应包含复制按钮"
        )
    }
}
