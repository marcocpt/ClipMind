import AppKit
import XCTest

/// F1.14 Phase 3 任务 5：标签筛选 UI Smoke。
///
/// 验证 FLT-002～006 的当前 Phase 可通过能力：
/// - 搜索 + 来源 + 标签使用 AND 交集；
/// - 多标签缩窄结果；
/// - 无匹配系统标签显示筛选空态；
/// - 移除无匹配标签恢复前一集合；
/// - 清除标签不改变搜索和来源 chip；
/// - 空数据库显示历史空态，不显示筛选空态。
///
/// 使用 `--UITEST_TAG_FILTER_FIXTURE` 注入 4 条固定夹具 ClipItem，
/// 通过真实主窗口搜索框、来源筛选和标签筛选执行端到端验证。
final class TagFilterUITests: XCTestCase
{
    // MARK: - 稳定夹具常量

    /// `tagFilterFixtureClips[0]` 的稳定 UUID（含"需求"，Pages，REQ+重要+待处理）。
    private let tagResult1ID = "00000000-0000-4000-8000-000000000301"
    /// `tagFilterFixtureClips[1]` 的稳定 UUID（含"需求"，Pages，REQ+重要）。
    private let tagResult2ID = "00000000-0000-4000-8000-000000000302"
    /// `tagFilterFixtureClips[2]` 的稳定 UUID（含"需求"，Xcode，CODE+重要+待处理）。
    private let tagResult3ID = "00000000-0000-4000-8000-000000000303"
    /// `tagFilterFixtureClips[3]` 的稳定 UUID（不含查询，Pages，REQ+重要+待处理）。
    private let tagResult4ID = "00000000-0000-4000-8000-000000000304"

    /// 用户标签"重要"的完整 ID（`user.<uuid>`）。
    private let importantTagID = "user.00000000-0000-4000-8000-000000000311"
    /// 用户标签"待处理"的完整 ID。
    private let pendingTagID = "user.00000000-0000-4000-8000-000000000312"
    /// 系统标签 LINK 的完整 ID（夹具中无条目关联此标签）。
    private let linkSystemTagID = "system.link"

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

    // MARK: - FLT-002：搜索 + 来源 + 标签 AND 交集

    /// 搜索"需求" + Pages + "重要"得到两个 resultId（tag-result-1、tag-result-2）。
    func testFilter_Search_Source_Tag_usesAND()
    {
        let app = launchWithFilterFixture()

        // 搜索"需求"（3 条匹配：tag-result-1/2/3）
        searchQuery(app, "需求")

        // 来源筛选只选 Pages（排除 Xcode → 排除 tag-result-3）
        deselectSource(app, "Xcode")

        // 标签筛选选"重要"（tag-result-1/2 都有"重要"）
        selectTagInFilter(app, importantTagID)

        // 验证结果：tag-result-1、tag-result-2 显示，tag-result-3/4 不显示
        verifyClipDisplayed(app, clipID: tagResult1ID, displayed: true)
        verifyClipDisplayed(app, clipID: tagResult2ID, displayed: true)
        verifyClipNotDisplayed(app, clipID: tagResult3ID)
        verifyClipNotDisplayed(app, clipID: tagResult4ID)
    }

    // MARK: - FLT-003：多标签交集缩窄

    /// 在 FLT-002 基础上再选"待处理"只剩一个（tag-result-1）。
    func testFilter_AddSecondTag_NarrowsToOne()
    {
        let app = launchWithFilterFixture()

        searchQuery(app, "需求")
        deselectSource(app, "Xcode")
        selectTagInFilter(app, importantTagID)
        selectTagInFilter(app, pendingTagID)

        // 验证结果：tag-result-1 显示，tag-result-2 不显示
        verifyClipDisplayed(app, clipID: tagResult1ID, displayed: true)
        verifyClipNotDisplayed(app, clipID: tagResult2ID)
    }

    // MARK: - FLT-004：无匹配系统标签显示筛选空态

    /// 选择无匹配系统标签（LINK）显示筛选空态。
    func testFilter_NonMatchingSystemTag_ShowsEmptyState()
    {
        let app = launchWithFilterFixture()

        searchQuery(app, "需求")
        deselectSource(app, "Xcode")
        selectTagInFilter(app, importantTagID)
        selectTagInFilter(app, pendingTagID)
        selectTagInFilter(app, linkSystemTagID)

        // 验证筛选空态出现
        let emptyState = app.descendants(matching: .any)["searchFilterEmptyState"].firstMatch
        XCTAssertTrue(
            emptyState.waitForExistence(timeout: 10),
            "选择无匹配标签应显示筛选空态"
        )
    }

    // MARK: - FLT-005：移除无匹配标签恢复结果

    /// 移除 LINK 标签恢复前一集合（tag-result-1）。
    func testFilter_RemoveNonMatchingTag_RestoresResults()
    {
        let app = launchWithFilterFixture()

        searchQuery(app, "需求")
        deselectSource(app, "Xcode")
        selectTagInFilter(app, importantTagID)
        selectTagInFilter(app, pendingTagID)
        selectTagInFilter(app, linkSystemTagID)

        // 确认空态
        let emptyState = app.descendants(matching: .any)["searchFilterEmptyState"].firstMatch
        XCTAssertTrue(emptyState.waitForExistence(timeout: 10))

        // 移除 LINK 标签（再次点击取消）
        selectTagInFilter(app, linkSystemTagID)

        // 验证 tag-result-1 恢复显示
        verifyClipDisplayed(app, clipID: tagResult1ID, displayed: true)
    }

    // MARK: - FLT-006：清除标签不改变搜索和来源

    /// 清除标签不改变搜索和来源 chip，结果回到搜索+来源的交集。
    func testFilter_ClearTags_KeepsSearchAndSource()
    {
        let app = launchWithFilterFixture()

        searchQuery(app, "需求")
        deselectSource(app, "Xcode")
        selectTagInFilter(app, importantTagID)
        selectTagInFilter(app, pendingTagID)

        // 清除全部标签筛选
        clearTagFilter(app)

        // 验证搜索和来源不变：tag-result-1、tag-result-2 显示
        verifyClipDisplayed(app, clipID: tagResult1ID, displayed: true)
        verifyClipDisplayed(app, clipID: tagResult2ID, displayed: true)
        verifyClipNotDisplayed(app, clipID: tagResult3ID)

        // 验证活动 chip 已移除
        let importantChip = app.descendants(matching: .any)["activeTagFilter_\(importantTagID)"].firstMatch
        XCTAssertFalse(importantChip.exists, "清除后「重要」活动 chip 应移除")
    }

    // MARK: - FLT-006b：空数据库显示历史空态

    /// 空数据库显示历史空态，不显示筛选空态。
    func testFilter_EmptyDatabase_ShowsHistoryEmptyState()
    {
        let app = XCUIApplication()
        app.launchArguments = ["--UITEST_SHOW_MAIN_WINDOW"]
        app.launch()
        app.activate()

        let emptyState = app.descendants(matching: .any)["historyEmptyState"].firstMatch
        XCTAssertTrue(
            emptyState.waitForExistence(timeout: 10),
            "空数据库应显示历史空态"
        )

        let filterEmptyState = app.descendants(matching: .any)["historyFilterEmptyState"].firstMatch
        XCTAssertFalse(
            filterEmptyState.exists,
            "空数据库不应显示筛选空态"
        )
    }

    // MARK: - 辅助方法

    /// 启动带标签筛选夹具的主窗口。
    private func launchWithFilterFixture() -> XCUIApplication
    {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_PREVIEW_DATA",
            "--UITEST_TAG_FILTER_FIXTURE"
        ]
        app.launch()
        app.activate()

        // 等待历史列表出现（初始显示全部 4 条夹具）
        let historyList = app.descendants(matching: .any)["historyList"].firstMatch
        XCTAssertTrue(
            historyList.waitForExistence(timeout: 10),
            "主窗口应显示历史列表"
        )

        // 等待 TagStore snapshot 加载完成：打开标签筛选 popover，
        // 确认用户标签「重要」出现在候选列表中。
        // snapshot 加载是异步的，historyList 出现不代表 snapshot 已就绪。
        let tagFilterPicker = app.buttons["tagFilterPicker"]
        XCTAssertTrue(
            tagFilterPicker.waitForExistence(timeout: 5),
            "标签筛选按钮应存在"
        )
        tagFilterPicker.click()
        let importantOption = app.buttons["tagFilterOption_\(importantTagID)"]
        XCTAssertTrue(
            importantOption.waitForExistence(timeout: 10),
            "TagStore snapshot 应加载完成，用户标签「重要」应出现在筛选候选中"
        )
        // 关闭 popover（再次点击 picker 或点击空白区域）
        tagFilterPicker.click()

        return app
    }

    /// 在搜索框输入查询并按回车提交。
    private func searchQuery(_ app: XCUIApplication, _ query: String)
    {
        let searchField = app.textFields["mainSearchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5), "搜索框应存在")
        searchField.click()
        searchField.typeText(query)
        searchField.typeText("\r")

        // 等待搜索结果列表出现
        let searchResults = app.descendants(matching: .any)["searchResultsList"].firstMatch
        XCTAssertTrue(
            searchResults.waitForExistence(timeout: 5),
            "搜索提交后应显示搜索结果列表"
        )
    }

    /// 在来源筛选菜单中取消选择指定来源。
    private func deselectSource(_ app: XCUIApplication, _ source: String)
    {
        // SwiftUI Menu 在 XCUITest 中不一定是 Button，用 descendants 兜底查询
        let picker = app.descendants(matching: .any)["sourceFilterPicker"].firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: 5), "来源筛选按钮应存在")
        picker.click()

        // Menu 展开后菜单项按文本查找
        let menuItem = app.menuItems[source]
        XCTAssertTrue(
            menuItem.waitForExistence(timeout: 3),
            "来源菜单项 \(source) 应存在"
        )
        menuItem.click()
    }

    /// 在标签筛选 popover 中切换指定标签的选择状态。
    private func selectTagInFilter(_ app: XCUIApplication, _ tagID: String)
    {
        let picker = app.buttons["tagFilterPicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5), "标签筛选按钮应存在")

        // 如果 popover 未打开，点击打开
        let option = app.buttons["tagFilterOption_\(tagID)"]
        if !option.exists
        {
            picker.click()
            XCTAssertTrue(
                option.waitForExistence(timeout: 5),
                "标签选项 \(tagID) 应存在"
            )
        }
        option.click()
    }

    /// 清除全部标签筛选。
    private func clearTagFilter(_ app: XCUIApplication)
    {
        let picker = app.buttons["tagFilterPicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))

        let clearButton = app.buttons["tagFilterClearButton"]
        if !clearButton.exists
        {
            picker.click()
            XCTAssertTrue(
                clearButton.waitForExistence(timeout: 5),
                "清除按钮应存在"
            )
        }
        clearButton.click()
    }

    /// 验证指定 clip 是否在当前结果列表中显示。
    ///
    /// 通过唯一的 `clipRow_<clipID>` accessibilityIdentifier 判断，不依赖标签 pill 或
    /// accessibilityValue（后者在 `.contain` 容器模式下不被 XCUITest 读取）。
    private func verifyClipDisplayed(
        _ app: XCUIApplication,
        clipID: String,
        displayed: Bool
    )
    {
        let clipRow = app.descendants(matching: .any)["clipRow_\(clipID)"].firstMatch
        if displayed
        {
            XCTAssertTrue(
                clipRow.waitForExistence(timeout: 10),
                "clip \(clipID) 应在结果列表中显示"
            )
        } else
        {
            XCTAssertFalse(
                clipRow.exists,
                "clip \(clipID) 不应在结果列表中显示"
            )
        }
    }

    /// 验证指定 clip 不在当前结果列表中（带超时等待 UI 更新）。
    private func verifyClipNotDisplayed(_ app: XCUIApplication, clipID: String)
    {
        let clipRow = app.descendants(matching: .any)["clipRow_\(clipID)"].firstMatch
        // 等待 UI 更新后 clip 行消失
        let predicate = NSPredicate { _, _ in !clipRow.exists }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: clipRow)
        let result = XCTWaiter().wait(for: [expectation], timeout: 10)
        XCTAssertTrue(
            result == .completed,
            "clip \(clipID) 应在筛选后从结果列表中消失"
        )
    }
}
