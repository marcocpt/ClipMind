import AppKit
import XCTest

/// F1.8 内置示例数据 UI 测试。
///
/// 覆盖 AC3（主窗口显示示例）、AC4（清除按钮）、AC5（真实数据保留）。
/// 禁止使用 --UITEST_PREVIEW_DATA（会让 MainWindow 使用 ClipTestData.previewClips 绕过注入逻辑）。
final class SampleDataUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        cleanUpDatabase()
    }

    override func tearDown() {
        // 每个测试结束后终止 App，确保下个测试从干净状态开始
        XCUIApplication().terminate()
        super.tearDown()
    }

    /// 清除上一轮测试残留的数据库文件。
    ///
    /// EncryptedStore 默认路径为 ~/Library/Application Support/ClipMind/clipmind.db。
    /// 删除 .db / .db-wal / .db-shm 三个文件确保每次测试从空库开始。
    private func cleanUpDatabase() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        let clipMindDir = appSupport.appendingPathComponent("ClipMind")
        let dbPath = clipMindDir.appendingPathComponent("clipmind.db")
        for suffix in ["", "-wal", "-shm"] {
            let path = dbPath.path + suffix
            try? FileManager.default.removeItem(atPath: path)
        }
    }

    // MARK: - UI-SD-01 首启显示示例（TC-F18-022 / TC-F18-023 / TC-F18-040）

    /// 验证首启引导完成后主窗口显示 ≥ 10 条示例。
    ///
    /// 使用 --UITEST_RESET_ONBOARDING 重置首启状态，完成引导流程后
    /// SampleDataSeeder 异步注入示例，等待 historyList 出现并验证 cell 数量。
    func testFirstLaunchShowsSamples() {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_RESET_ONBOARDING",
            "--UITEST_RESET_SETTINGS"
        ]
        app.launch()
        app.activate()

        // 完成引导流程：welcome → permissions → apiKey → privacy → completed
        let startButton = app.buttons["开始使用"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 20), "欢迎页应出现")
        startButton.click()
        app.activate()

        let nextButton1 = app.buttons["下一步"]
        XCTAssertTrue(nextButton1.waitForExistence(timeout: 5))
        nextButton1.click()
        app.activate()

        // apiKey 步骤：点击跳过，弹出 alert 确认
        let skipButton = app.buttons["跳过"]
        XCTAssertTrue(skipButton.waitForExistence(timeout: 5))
        skipButton.click()
        app.activate()

        // 等待跳过确认弹窗（onChange 异步触发，可能需要时间）
        // macOS SwiftUI .alert 以 sheet 形式呈现，用 descendants 兜底查询
        let confirm = app.descendants(matching: .any).buttons["确定"].firstMatch
        XCTAssertTrue(
            confirm.waitForExistence(timeout: 5),
            "点击跳过后应弹出确认对话框"
        )
        confirm.click()
        app.activate()

        // privacy 步骤：点击完成按钮
        let finishButton = app.buttons["开始使用 ClipMind"]
        XCTAssertTrue(finishButton.waitForExistence(timeout: 5))
        finishButton.click()

        // TC-F18-040: 引导完成后主窗口应立即可交互（不等注入完成）
        let mainWindow = app.windows.firstMatch
        XCTAssertTrue(mainWindow.waitForExistence(timeout: 5), "主窗口应立即显示")

        // 等待 historyList 出现（注入异步执行，需等待 clipDidUpdateNotification 触发刷新）
        let historyList = app.descendants(matching: .any)["historyList"].firstMatch
        XCTAssertTrue(
            historyList.waitForExistence(timeout: 20),
            "注入完成后应显示历史列表"
        )

        // 等待 cell 数量稳定（轮询直到 >= 10 或超时）
        let deadline = Date().addingTimeInterval(15)
        while Date() < deadline {
            if historyList.cells.count >= 10 { break }
            Thread.sleep(forTimeInterval: 0.5)
        }

        XCTAssertGreaterThanOrEqual(
            historyList.cells.count, 10,
            "首启后应显示至少 10 条示例，实际 \(historyList.cells.count)"
        )

        // TC-F18-023: 验证类型标签可见
        let codeTag = app.descendants(matching: .any)["typeTag_code"].firstMatch
        XCTAssertTrue(codeTag.waitForExistence(timeout: 5), "应存在 CODE 类型标签")
        let errorTag = app.descendants(matching: .any)["typeTag_error"].firstMatch
        XCTAssertTrue(errorTag.waitForExistence(timeout: 5), "应存在 ERROR 类型标签")
    }

    // MARK: - UI-SD-02 清除示例数据（TC-F18-024 / TC-F18-025 / TC-F18-026）

    /// 验证设置面板清除示例数据按钮可用。
    ///
    /// 预置 13 条示例 + 2 条真实数据（--UITEST_PREPOPULATE_SAMPLE_AND_REAL），
    /// 打开通用 Tab，点击清除按钮，确认后验证 cell 数量从 15 变为 2。
    func testClearSamplesRemovesFromUI() {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_RESET_SETTINGS",
            "--UITEST_INITIAL_TAB=general",
            "--UITEST_PREPOPULATE_SAMPLE_AND_REAL"
        ]
        app.launch()
        app.activate()

        // 等待主窗口加载并显示历史列表
        let historyList = app.descendants(matching: .any)["historyList"].firstMatch
        XCTAssertTrue(
            historyList.waitForExistence(timeout: 10),
            "主窗口应显示历史列表"
        )

        // 等待预置数据加载（13 示例 + 2 真实 = 15 条）
        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline {
            if historyList.cells.count >= 15 { break }
            Thread.sleep(forTimeInterval: 0.5)
        }
        XCTAssertEqual(
            historyList.cells.count, 15,
            "预置后应有 15 条（13 示例 + 2 真实），实际 \(historyList.cells.count)"
        )

        // 打开设置面板
        let settingsButton = app.buttons["settingsButton"].firstMatch
        XCTAssertTrue(settingsButton.exists)
        settingsButton.click()
        app.activate()

        // 等待通用 Tab 内容加载
        let clearButton = app.buttons["clearSampleDataButton"]
        XCTAssertTrue(
            clearButton.waitForExistence(timeout: 5),
            "通用 Tab 应有清除示例数据按钮"
        )

        // 点击清除按钮
        clearButton.click()

        // 等待确认对话框弹出，点击"清除示例数据"（destructive）
        let destructiveButton = app.sheets.buttons["清除示例数据"].firstMatch
        XCTAssertTrue(
            destructiveButton.waitForExistence(timeout: 3),
            "应弹出确认对话框含'清除示例数据'选项"
        )
        destructiveButton.click()

        // 等待 ClipStore 刷新（clipDidUpdateNotification 触发 loadClips）
        Thread.sleep(forTimeInterval: 1.0)

        // 验证 cell 数量降为 2（仅剩真实数据）
        let deadlineAfter = Date().addingTimeInterval(10)
        while Date() < deadlineAfter {
            if historyList.cells.count <= 2 { break }
            Thread.sleep(forTimeInterval: 0.5)
        }
        XCTAssertEqual(
            historyList.cells.count, 2,
            "清除示例后应剩 2 条真实数据，实际 \(historyList.cells.count)"
        )
    }

    // MARK: - UI-SD-03 清除后真实数据保留（TC-F18-027）

    /// 验证清除示例数据后真实数据仍显示。
    ///
    /// 此测试与 UI-SD-02 共享预置数据，但单独验证真实数据可见性。
    /// 通过 cell 数量 == 2 间接证明真实数据保留（UI 层不访问内部 store）。
    func testRealDataPreservedAfterClear() {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_RESET_SETTINGS",
            "--UITEST_INITIAL_TAB=general",
            "--UITEST_PREPOPULATE_SAMPLE_AND_REAL"
        ]
        app.launch()
        app.activate()

        let historyList = app.descendants(matching: .any)["historyList"].firstMatch
        XCTAssertTrue(historyList.waitForExistence(timeout: 10))

        // 等待预置数据加载
        let deadlineLoad = Date().addingTimeInterval(10)
        while Date() < deadlineLoad {
            if historyList.cells.count >= 15 { break }
            Thread.sleep(forTimeInterval: 0.5)
        }

        // 清除示例数据
        let settingsButton = app.buttons["settingsButton"].firstMatch
        settingsButton.click()
        app.activate()

        let clearButton = app.buttons["clearSampleDataButton"]
        XCTAssertTrue(clearButton.waitForExistence(timeout: 5))
        clearButton.click()

        let destructiveButton = app.sheets.buttons["清除示例数据"].firstMatch
        XCTAssertTrue(destructiveButton.waitForExistence(timeout: 3))
        destructiveButton.click()

        // 等待刷新
        Thread.sleep(forTimeInterval: 1.0)

        // 验证真实数据保留（cell 数量 == 2）
        let deadlineAfter = Date().addingTimeInterval(10)
        while Date() < deadlineAfter {
            if historyList.cells.count <= 2 { break }
            Thread.sleep(forTimeInterval: 0.5)
        }
        XCTAssertEqual(
            historyList.cells.count, 2,
            "清除后应保留 2 条真实数据"
        )

        // 验证历史列表非空（未进入空状态）
        let emptyState = app.descendants(matching: .any)["historyEmptyState"].firstMatch
        XCTAssertFalse(emptyState.exists, "仍有真实数据时不应显示空状态")
    }

    // MARK: - UI-SD-04 确认对话框取消按钮（补充测试）

    /// 验证点击清除按钮后取消不清除数据。
    func testClearConfirmationCancelDoesNotClear() {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_RESET_SETTINGS",
            "--UITEST_INITIAL_TAB=general",
            "--UITEST_PREPOPULATE_SAMPLE_AND_REAL"
        ]
        app.launch()
        app.activate()

        let historyList = app.descendants(matching: .any)["historyList"].firstMatch
        XCTAssertTrue(historyList.waitForExistence(timeout: 10))

        // 等待预置数据
        let deadlineLoad = Date().addingTimeInterval(10)
        while Date() < deadlineLoad {
            if historyList.cells.count >= 15 { break }
            Thread.sleep(forTimeInterval: 0.5)
        }

        // 打开清除确认对话框
        let settingsButton = app.buttons["settingsButton"].firstMatch
        settingsButton.click()
        app.activate()

        let clearButton = app.buttons["clearSampleDataButton"]
        XCTAssertTrue(clearButton.waitForExistence(timeout: 5))
        clearButton.click()

        // 点击取消
        let cancelButton = app.sheets.buttons["取消"].firstMatch
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 3))
        cancelButton.click()

        Thread.sleep(forTimeInterval: 0.5)

        // 数据应不变
        XCTAssertEqual(
            historyList.cells.count, 15,
            "取消清除后数据应不变"
        )
    }

    // MARK: - UI-SD-05 UI 搜索"报错"命中 error 类型示例（TC-F18-033）

    /// 验证主窗口搜索框输入"报错"后命中 error 类型示例。
    ///
    /// 注意：此测试验证的是 MainWindow.performSearch 的**文本匹配**（localizedCaseInsensitiveContains），
    /// 而非 SearchService 的语义搜索。AC2 的语义搜索由 SampleDataSearchTests（XCTest）验证。
    /// UI 层的语义搜索验证待 SearchService 接入 MainWindow 后补充。
    ///
    /// 使用 --UITEST_PREPOPULATE_SAMPLE_AND_REAL 预置数据（含 error 示例），
    /// 在搜索框输入"报错"后等待搜索结果列表出现，验证结果包含 ERROR 类型标签。
    func testUISearchErrorHitsSample() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_PREPOPULATE_SAMPLE_AND_REAL",
            "--UITEST_INITIAL_TAB=general"
        ]
        app.launch()
        app.activate()

        // 等待主窗口列表出现
        let historyList = app.descendants(matching: .any)["historyList"].firstMatch
        XCTAssertTrue(historyList.waitForExistence(timeout: 20), "主窗口历史列表应出现")

        // 在搜索框输入"报错"（使用粘贴板避免 IME 干扰 typeText 合成事件超时）
        let searchField = app.textFields["mainSearchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5), "搜索框应存在")
        searchField.click()

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString("报错", forType: .string)
        app.typeKey("v", modifierFlags: .command)

        // 等待搜索结果列表出现，验证包含 error 类型标签
        let searchResultsList = app.descendants(matching: .any)["searchResultsList"].firstMatch
        XCTAssertTrue(searchResultsList.waitForExistence(timeout: 10), "搜索结果列表应出现")
        let errorTag = app.descendants(matching: .any)["typeTag_error"].firstMatch
        XCTAssertTrue(errorTag.waitForExistence(timeout: 5), "搜索结果应包含 ERROR 类型示例")
    }
}
