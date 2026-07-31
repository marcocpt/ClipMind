import AppKit
import XCTest

/// F1.14 Phase 5 任务 5 步骤 2：标签 UI 性能测试。
///
/// 三个真实入口分别测量（每项 20 样本，nearest-rank p95，升序第 19 个=index 18）：
/// - 激活标签到 `tagPickerSearch` hittable ≤ 200ms；
/// - 确认创建到新 `clipTag_*` hittable ≤ 200ms；
/// - 无迁移/迁移交替启动，`mainWindowInteractive` 差值 p95 ≤ 200ms。
///
/// 使用显式 `ContinuousClock` 样本；不以进程启动结束替代可交互结果。
/// 运行环境：macOS 15 arm64 `ClipMind-Dev` / `ReleaseDev`（phase-5 计划）。
///
/// - Note: 迁移启动样本当前使用 `--UITEST_TAG_MIGRATION_FIXTURE`（100 条 legacy）。
///   phase-5 计划指定 1000 条；扩容到 1000 条需在 `ClipTestData` 增加夹具，
///   属于生产代码改动，本任务范围外（task 约束：不修改生产代码）。
final class TagPerformanceUITests: XCTestCase
{
    // MARK: - 常量

    private let sampleCount = 20
    private let p95Index = 18
    private let uiP95LimitMs = 200.0

    /// `previewClips[0]` 的稳定 UUID（code 类型，有标签夹具）。
    private let firstClipIDString = "00000000-0000-4000-8000-000000000001"
    /// 第一个用户标签 ID（标准夹具 "工作"）。
    private let firstUserTagID = "user.00000000-0000-4000-8000-000000000101"

    // MARK: - setUp / tearDown

    override func setUp()
    {
        super.setUp()
        continueAfterFailure = false
    }

    override func tearDown()
    {
        XCUIApplication().terminate()
        super.tearDown()
    }

    // MARK: - UIPERF-1：激活标签到 picker 搜索框 hittable ≤ 200ms

    /// 每次样本独立启动，点击 pill 后测量到 `tagPickerSearch` hittable 的耗时。
    func testUIPerformance_PickerAppear_p95Under200ms()
    {
        var samples: [Double] = []
        for index in 0..<sampleCount
        {
            let app = launchApp(
                args: ["--UITEST_SHOW_MAIN_WINDOW", "--UITEST_PREVIEW_DATA", "--UITEST_TAG_FIXTURE"],
                tag: "picker-\(index)"
            )

            let pill = app.buttons["clipTag_\(firstClipIDString)_\(firstUserTagID)"]
            XCTAssertTrue(pill.waitForExistence(timeout: 10), "标签 pill 应存在")

            let clock = ContinuousClock()
            let start = clock.now
            pill.click()
            let searchField = app.textFields["tagPickerSearch"]
            let appeared = searchField.waitForExistence(timeout: 5)
            let elapsed = clock.now - start
            XCTAssertTrue(appeared, "picker 搜索框应可交互")
            samples.append(milliseconds(elapsed))

            app.terminate()
            cleanUpDatabase()
        }
        assertP95(samples, name: "tagPickerAppear")
    }

    // MARK: - UIPERF-2：确认创建到新 clipTag_* hittable ≤ 200ms

    /// 每次样本独立启动，走完整创建流程，测量从点击确认到新 pill hittable 的耗时。
    func testUIPerformance_TagCreateConfirm_p95Under200ms()
    {
        var samples: [Double] = []
        for index in 0..<sampleCount
        {
            let tagName = "性能标签\(index)"
            let app = launchApp(
                args: ["--UITEST_SHOW_MAIN_WINDOW", "--UITEST_PREVIEW_DATA", "--UITEST_TAG_FIXTURE"],
                tag: "create-\(index)"
            )

            let pill = app.buttons["clipTag_\(firstClipIDString)_\(firstUserTagID)"]
            XCTAssertTrue(pill.waitForExistence(timeout: 10))
            pill.click()

            let searchField = app.textFields["tagPickerSearch"]
            XCTAssertTrue(searchField.waitForExistence(timeout: 5))
            searchField.click()
            searchField.typeText(tagName)

            let createEntry = app.buttons["tagCreateEntry"]
            XCTAssertTrue(createEntry.waitForExistence(timeout: 3), "创建入口应出现")
            createEntry.click()

            let nameField = app.textFields["tagCreateNameField"]
            XCTAssertTrue(nameField.waitForExistence(timeout: 3))
            nameField.click()
            nameField.typeText(tagName)

            // 测量：从点击确认到新 clipTag_* pill hittable
            let clipRow = app.descendants(matching: .any)["clipRow_\(firstClipIDString)"].firstMatch
            let tagButtons = clipRow.buttons.matching(
                NSPredicate(format: "identifier BEGINSWITH 'clipTag_'")
            )
            let initialCount = tagButtons.count

            let confirmButton = app.buttons["tagCreateConfirm"]
            XCTAssertTrue(confirmButton.exists, "确认按钮应存在")

            let clock = ContinuousClock()
            let start = clock.now
            confirmButton.click()

            let predicate = NSPredicate { _, _ in tagButtons.count == initialCount + 1 }
            let expectation = XCTNSPredicateExpectation(predicate: predicate, object: nil)
            let result = XCTWaiter().wait(for: [expectation], timeout: 10)
            let elapsed = clock.now - start
            XCTAssertTrue(result == .completed, "新标签 pill 应可交互")
            samples.append(milliseconds(elapsed))

            app.terminate()
            cleanUpDatabase()
        }
        assertP95(samples, name: "tagCreateConfirm")
    }

    // MARK: - UIPERF-3：无迁移/迁移交替启动差值 p95 ≤ 200ms

    /// 20 组交替启动（无迁移 + 迁移），测量每组 `mainWindowInteractive` hittable 差值。
    func testUIPerformance_MigrationLaunchDelta_p95Under200ms()
    {
        var diffs: [Double] = []
        for index in 0..<sampleCount
        {
            // 无迁移启动
            let noMigApp = launchApp(
                args: ["--UITEST_SHOW_MAIN_WINDOW", "--UITEST_PREVIEW_DATA"],
                tag: "nomsig-\(index)"
            )
            let noMigMs = measureToMainWindowInteractive(noMigApp)
            noMigApp.terminate()
            cleanUpDatabase()

            // 迁移启动（100 条 legacy 夹具）
            let migApp = launchApp(
                args: ["--UITEST_SHOW_MAIN_WINDOW", "--UITEST_TAG_MIGRATION_FIXTURE"],
                tag: "mig-\(index)"
            )
            let migMs = measureToMainWindowInteractive(migApp)
            migApp.terminate()
            cleanUpDatabase()

            diffs.append(migMs - noMigMs)
        }
        assertP95(diffs, name: "migrationLaunchDelta")
    }

    // MARK: - 辅助

    /// 清理共享数据库，确保每次启动为干净状态。
    private func cleanUpDatabase()
    {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        let dbPath = appSupport.appendingPathComponent("ClipMind/clipmind.db")
        for suffix in ["", "-wal", "-shm"]
        {
            try? FileManager.default.removeItem(atPath: dbPath.path + suffix)
        }
    }

    /// 启动 App 并激活。
    @discardableResult
    private func launchApp(args: [String], tag: String) -> XCUIApplication
    {
        let app = XCUIApplication()
        app.launchArguments = args
        app.launchEnvironment["UITEST_LAUNCH_TAG"] = tag
        app.launch()
        app.activate()
        return app
    }

    /// 测量从当前时刻到 `mainWindowInteractive` hittable 的毫秒数。
    private func measureToMainWindowInteractive(_ app: XCUIApplication) -> Double
    {
        let clock = ContinuousClock()
        let start = clock.now
        let interactive = app.descendants(matching: .any)["mainWindowInteractive"].firstMatch
        let appeared = interactive.waitForExistence(timeout: 30)
        let elapsed = clock.now - start
        XCTAssertTrue(appeared, "主窗口应可交互（mainWindowInteractive）")
        return milliseconds(elapsed)
    }

    /// Duration 转毫秒。
    private func milliseconds(_ duration: Duration) -> Double
    {
        let (seconds, attoseconds) = duration.components
        return Double(seconds) * 1000.0 + Double(attoseconds) / 1e15
    }

    /// 计算 nearest-rank p95 并断言；保存原始样本为 attachment。
    private func assertP95(_ samples: [Double], name: String)
    {
        let sorted = samples.sorted()
        let p95 = sorted[p95Index]
        let raw = samples.enumerated().map
        {
            "\($0.offset + 1)=\(String(format: "%.3f", $0.element))ms"
        }.joined(separator: ", ")

        XCTContext.runActivity(named: "UIPERF \(name)") { activity in
            let summaryLine = "p95=\(String(format: "%.3f", p95))ms limit=\(uiP95LimitMs)ms\nraw: \(raw)"
            let summary = XCTAttachment(string: summaryLine)
            summary.name = "uiperf-\(name)"
            summary.lifetime = .keepAlways
            activity.add(summary)
        }
        XCTAssertLessThan(
            p95,
            uiP95LimitMs,
            "\(name) p95 应 ≤ \(uiP95LimitMs)ms，实际 \(p95)ms"
        )
    }
}
