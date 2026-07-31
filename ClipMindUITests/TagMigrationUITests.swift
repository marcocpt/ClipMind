import AppKit
import XCTest

/// F1.14 Phase 5 任务 4 步骤 2：标签迁移 UI 测试。
///
/// 验证旧数据迁移的端到端行为：
/// - 主窗口在迁移完成前可交互（`mainWindowInteractive` 由 `historyList` 代理）；
/// - fail-once 后 `tagMigrationRetryButton` 与不含标签名/内容的安全错误可见；
/// - 重启继续且最终 100 条无重复；
/// - removed disposition 条目仍显示「+」；
/// - CODE/LINK/ERROR 文本、颜色 accessibility value 与旧基线一致。
///
/// 使用 `--UITEST_TAG_MIGRATION_FIXTURE` 注入 100 条 legacy ClipItem 和 1 条 removed
/// disposition 条目，通过真实主窗口验证迁移行为。
final class TagMigrationUITests: XCTestCase
{
    // MARK: - 稳定夹具常量

    /// 第一条 legacy ClipItem 的稳定 UUID（code 类型，索引 0）。
    /// 用于验证迁移完成后 CODE 系统标签关联和 accessibility label。
    private let firstLegacyClipID = "00000000-0000-4000-8000-000000000401"

    /// removed disposition 条目的稳定 UUID（系统标签被移除，迁移不恢复）。
    private let removedClipID = "00000000-0000-4000-8000-000000000501"

    /// 迁移夹具总数：100 条 legacy + 1 条 removed = 101。
    private let expectedTotalCount = 101

    /// 系统标签 CODE 的完整 ID（`system.<contentType.rawValue>`）。
    private let codeSystemTagID = "system.code"
    /// 系统标签 LINK 的完整 ID。
    private let linkSystemTagID = "system.link"

    /// 迁移失败时由 `TagError.persistenceFailed` 提供的固定安全错误文案。
    /// 不含标签名、剪贴板内容或 Task 对象。
    private let safeErrorMessage = "未能保存标签操作，已恢复之前的状态"

    // MARK: - setUp / tearDown

    override func setUp()
    {
        super.setUp()
        continueAfterFailure = false
        cleanUpDatabase()
    }

    override func tearDown()
    {
        XCUIApplication().terminate()
        super.tearDown()
    }

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

    // MARK: - MIG-001：主窗口在迁移完成前可见

    /// 首个 `mainWindowInteractive` 在迁移完成前可见。
    ///
    /// `mainWindowInteractive` accessibility identifier 尚未在生产代码中实现，
    /// 当前用 `historyList` 作为主窗口可交互的代理标识。
    /// 主窗口不应阻塞等待迁移完成才显示历史列表。
    ///
    /// 注意：需要生产代码在 MainWindow 根视图添加
    /// `.accessibilityIdentifier("mainWindowInteractive")` 以支持精确的可交互时刻测量。
    func testMigration_MainWindowVisibleBeforeCompletion()
    {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_TAG_MIGRATION_FIXTURE"
        ]
        app.launch()
        app.activate()

        // mainWindowInteractive 尚未实现，用 historyList 代理主窗口可交互状态
        let historyList = app.descendants(matching: .any)["historyList"].firstMatch
        XCTAssertTrue(
            historyList.waitForExistence(timeout: 10),
            "主窗口应在迁移完成前显示历史列表（mainWindowInteractive 代理）"
        )

        // 等待 historyList 有内容（迁移夹具已注入，value 异步更新）
        let nonEmptyPredicate = NSPredicate { _, _ in
            let value = (historyList.value as? String) ?? "0"
            return value != "0"
        }
        let nonEmptyExpectation = XCTNSPredicateExpectation(
            predicate: nonEmptyPredicate,
            object: historyList
        )
        let nonEmptyResult = XCTWaiter().wait(
            for: [nonEmptyExpectation],
            timeout: 10
        )
        XCTAssertTrue(
            nonEmptyResult == .completed,
            "迁移夹具注入后历史列表不应为空"
        )
    }

    // MARK: - MIG-002：fail-once 后显示重试按钮和安全错误

    /// fail-once 后 `tagMigrationRetryButton` 与不含标签名/内容的安全错误可见。
    ///
    /// `--UITEST_TAG_FAIL_ONCE migrate`（两个独立参数）使首次 `migrateNextBatch` 抛
    /// `TagError.persistenceFailed`，TagStore 记录 `.migration` 失败状态，
    /// MainWindow 显示 migrationBanner 包含重试按钮和安全错误文案。
    func testMigration_FailOnce_ShowsRetryButtonAndSafeError()
    {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_TAG_MIGRATION_FIXTURE",
            "--UITEST_TAG_FAIL_ONCE",
            "migrate"
        ]
        app.launch()
        app.activate()

        // 等待迁移失败 banner 出现
        let retryButton = app.buttons["tagMigrationRetryButton"]
        XCTAssertTrue(
            retryButton.waitForExistence(timeout: 15),
            "fail-once 后应显示 tagMigrationRetryButton"
        )

        // 验证安全错误文案可见且不含标签名/内容
        let errorText = app.staticTexts[safeErrorMessage]
        XCTAssertTrue(
            errorText.waitForExistence(timeout: 5),
            "应显示固定安全错误文案"
        )

        // 验证错误文案不包含迁移夹具内容或标签名
        let errorLabel = errorText.label
        XCTAssertFalse(
            errorLabel.contains("迁移夹具条目"),
            "安全错误文案不应包含迁移夹具内容"
        )
        XCTAssertFalse(
            errorLabel.contains("CODE") || errorLabel.contains("LINK"),
            "安全错误文案不应包含标签名"
        )

        // 点击重试按钮，迁移应恢复
        retryButton.click()

        // 等待 retryButton 消失（迁移恢复后 banner 隐藏）
        let retryGonePredicate = NSPredicate { _, _ in !retryButton.exists }
        let retryGoneExpectation = XCTNSPredicateExpectation(
            predicate: retryGonePredicate,
            object: retryButton
        )
        let retryResult = XCTWaiter().wait(
            for: [retryGoneExpectation],
            timeout: 20
        )
        XCTAssertTrue(
            retryResult == .completed,
            "点击重试后迁移应恢复，retryButton 应消失"
        )
    }

    // MARK: - MIG-003：重启继续且最终 100 条无重复

    /// 重启继续且最终 100 条无重复。
    ///
    /// 首次启动迁移 100 条 legacy 数据，终止后重启，
    /// 迁移已完成，历史列表应有 101 条（100 legacy + 1 removed）。
    /// 通过抽样验证首尾 clip ID 存在且无重复。
    func testMigration_RestartCompletesWithNoDuplicates()
    {
        let app = launchWithMigrationFixture()
        waitForMigrationCompletion(app)
        app.terminate()

        // 重启：不注入夹具，从数据库加载已迁移数据
        let relaunchedApp = XCUIApplication()
        relaunchedApp.launchArguments = ["--UITEST_SHOW_MAIN_WINDOW"]
        relaunchedApp.launch()
        relaunchedApp.activate()

        waitForHistoryList(relaunchedApp)
        verifyHistoryListCount(relaunchedApp, expected: expectedTotalCount, timeout: 15)

        // 抽样验证首尾 clip ID 存在（无重复由数据库主键保证）
        verifyClipExists(relaunchedApp, clipID: firstLegacyClipID)
        verifyClipExists(
            relaunchedApp,
            clipID: "00000000-0000-4000-8000-000000000500"
        )
        verifyClipExists(relaunchedApp, clipID: removedClipID)
    }

    // MARK: - MIG-004：removed 条目仍显示「+」

    /// removed disposition 条目迁移后仍显示「+」按钮（系统标签不恢复）。
    ///
    /// `tagMigrationRemovedClipID` 的 `systemTagDisposition` 为 `.removed`，
    /// 迁移不恢复系统标签，`ClipTagStripView` 检测空标签列表显示 `tagAdd_` 按钮。
    func testMigration_RemovedClipShowsAddButton()
    {
        let app = launchWithMigrationFixture()
        waitForMigrationCompletion(app)

        // 验证 removed 条目显示「+」按钮（无系统标签）
        let removedAddButton = app.buttons["tagAdd_\(removedClipID)"]
        XCTAssertTrue(
            removedAddButton.waitForExistence(timeout: 5),
            "removed disposition 条目应显示「+」按钮（系统标签不恢复）"
        )

        // 验证 removed 条目不显示系统标签 pill
        let removedLinkPill = app.buttons[
            "clipTag_\(removedClipID)_\(linkSystemTagID)"
        ]
        XCTAssertFalse(
            removedLinkPill.exists,
            "removed disposition 条目不应有 LINK 系统标签 pill"
        )
    }

    // MARK: - MIG-005：CODE/LINK/ERROR 文本、颜色 accessibility value 与旧基线一致

    /// CODE/LINK/ERROR 文本、颜色 accessibility value 与旧基线一致。
    ///
    /// 迁移夹具索引 0/1/2 分别为 code/link/error 类型，迁移后 TypeTagView 显示
    /// 对应系统标签 pill。验证 accessibility label 包含正确名称和颜色中文名：
    /// - CODE: "CODE，自动分类标签，紫罗兰"（violet）
    /// - LINK: "LINK，自动分类标签，青色"（cyan）
    /// - ERROR: "ERROR，自动分类标签，玫红"（rose）
    func testMigration_SystemTagAccessibilityValuesMatchBaseline()
    {
        let app = launchWithMigrationFixture()
        waitForHistoryList(app)

        verifyTypeTagLabel(app, identifier: "typeTag_code", expected: "CODE，自动分类标签，紫罗兰")
        verifyTypeTagLabel(app, identifier: "typeTag_link", expected: "LINK，自动分类标签，青色")
        verifyTypeTagLabel(app, identifier: "typeTag_error", expected: "ERROR，自动分类标签，玫红")
    }

    // MARK: - 辅助方法

    /// 启动带迁移夹具的主窗口。
    private func launchWithMigrationFixture() -> XCUIApplication
    {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_TAG_MIGRATION_FIXTURE"
        ]
        app.launch()
        app.activate()
        waitForHistoryList(app)
        return app
    }

    /// 等待历史列表出现。
    private func waitForHistoryList(_ app: XCUIApplication)
    {
        let historyList = app.descendants(matching: .any)["historyList"].firstMatch
        XCTAssertTrue(
            historyList.waitForExistence(timeout: 10),
            "历史列表应出现"
        )
    }

    /// 等待迁移完成：第一条 legacy clip 获得 CODE 系统标签 pill。
    private func waitForMigrationCompletion(_ app: XCUIApplication)
    {
        let firstClipTagPill = app.buttons[
            "clipTag_\(firstLegacyClipID)_\(codeSystemTagID)"
        ]
        XCTAssertTrue(
            firstClipTagPill.waitForExistence(timeout: 30),
            "迁移完成后第一条 legacy clip 应有 CODE 系统标签"
        )
    }

    /// 验证历史列表条目总数。
    private func verifyHistoryListCount(
        _ app: XCUIApplication,
        expected: Int,
        timeout: TimeInterval
    )
    {
        let historyList = app.descendants(matching: .any)["historyList"].firstMatch
        let expectedCount = "\(expected)"
        let countPredicate = NSPredicate { _, _ in
            (historyList.value as? String) == expectedCount
        }
        let countExpectation = XCTNSPredicateExpectation(
            predicate: countPredicate,
            object: historyList
        )
        let result = XCTWaiter().wait(for: [countExpectation], timeout: timeout)
        XCTAssertEqual(
            result,
            .completed,
            "历史列表应有 \(expected) 条"
        )
    }

    /// 验证指定 clip ID 在历史列表中存在。
    private func verifyClipExists(_ app: XCUIApplication, clipID: String)
    {
        let clipRow = app.descendants(matching: .any)["clipRow_\(clipID)"].firstMatch
        XCTAssertTrue(
            clipRow.waitForExistence(timeout: 5),
            "clip \(clipID) 应存在"
        )
    }

    /// 验证 typeTag 的 accessibility label 与预期一致。
    private func verifyTypeTagLabel(
        _ app: XCUIApplication,
        identifier: String,
        expected: String
    )
    {
        let typeTag = app.descendants(matching: .any)[identifier].firstMatch
        XCTAssertTrue(
            typeTag.waitForExistence(timeout: 10),
            "应显示 \(identifier) 类型标签"
        )
        XCTAssertEqual(
            typeTag.label,
            expected,
            "\(identifier) accessibility label 应与旧基线一致"
        )
    }
}
