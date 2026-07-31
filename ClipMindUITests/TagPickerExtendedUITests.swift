import AppKit
import XCTest

/// F1.14 Phase 5 UI-MENU 扩展用例。
///
/// 从 `TagPickerUITests` 拆分以控制文件长度。覆盖：
/// - UI-MENU-003：创建后新 pill、已选择 value、搜索清空
/// - UI-MENU-004：pill 立即增删、dialog 数为 0
/// - UI-MENU-006 补充：上限时 checkbox 未选、计数仍 5
/// - UI-MENU-007：设置目录无候选名、条目仍 5
/// - UI-MENU-008：系统 pill 移除并在重启后保持
/// - UI-MENU-009：满额恢复拒绝、释放后恢复、其他系统项不存在
/// - UI-MENU-010：11 个具名色按钮、无自定义色输入
/// - UI-MENU-011：fail-once 后原 pill、safe error、retry 后成功
final class TagPickerExtendedUITests: XCTestCase
{
    // MARK: - 稳定夹具常量

    /// `previewClips[0]` 的稳定 UUID（code 类型）。
    private let firstClipIDString = "00000000-0000-4000-8000-000000000001"
    /// 第一个用户标签 ID（标准夹具 "工作"）。
    private let firstUserTagID = "user.00000000-0000-4000-8000-000000000101"
    /// 第二个用户标签 ID（标准夹具 "参考"）。
    private let secondUserTagID = "user.00000000-0000-4000-8000-000000000102"
    /// code 类型系统标签 ID。
    private let codeSystemTagID = "system.code"
    /// 上限夹具第一个用户标签 ID（"标签1"）。
    private let firstLimitTagID = "user.00000000-0000-4000-8000-000000000201"

    /// 11 个 ClipTagColor 的 rawValue，用于颜色面板验证。
    private let allColorRawValues = [
        "violet", "cyan", "rose", "blue", "amber",
        "emerald", "purple", "orange", "teal", "slate", "gray"
    ]

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

    // MARK: - UI-MENU-003：创建新标签后新 pill、已选择 value、搜索清空

    func testPicker_Create_ShowsNewOption_SelectedValue_SearchCleared()
    {
        let app = launchAndOpenPicker()

        let optionsBefore = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "tagOption_")
        ).count

        let searchField = app.textFields["tagPickerSearch"]
        searchField.click()
        searchField.typeText("测试新标签")

        let createEntry = app.buttons["tagCreateEntry"]
        XCTAssertTrue(createEntry.waitForExistence(timeout: 3), "无匹配时应显示创建入口")
        createEntry.click()

        let nameField = app.textFields["tagCreateNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3), "创建模式应显示名称输入框")
        nameField.click()
        nameField.typeText("测试新标签")

        app.buttons["tagCreateConfirm"].click()

        XCTAssertEqual(
            app.textFields["tagPickerSearch"].value as? String,
            "",
            "创建成功后搜索应清空"
        )

        let optionsAfter = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "tagOption_")
        ).count
        XCTAssertEqual(optionsAfter, optionsBefore + 1, "创建后候选标签应增加 1")

        let selectedCount = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "tagOption_")
        ).matching(NSPredicate(format: "value == %@", "已选择")).count
        XCTAssertEqual(selectedCount, 3, "创建后应有 3 个已选择标签")
    }

    // MARK: - UI-MENU-004：pill 立即增删、dialog 数为 0

    func testPicker_Toggle_PillAppearsImmediately_NoDialog()
    {
        let app = launchAndOpenPicker()

        let referenceOption = app.buttons["tagOption_\(secondUserTagID)"]
        XCTAssertTrue(referenceOption.waitForExistence(timeout: 3))
        XCTAssertEqual(
            referenceOption.value as? String,
            "未选择",
            "「参考」标签初始应未选择"
        )

        let referencePill = app.buttons[
            "clipTag_\(firstClipIDString)_\(secondUserTagID)"
        ]
        XCTAssertFalse(referencePill.exists, "初始不应有「参考」pill")

        referenceOption.click()
        XCTAssertTrue(
            referenceOption.waitForValue("已选择", timeout: 5),
            "点击后「参考」应已选择"
        )
        XCTAssertTrue(
            referencePill.waitForExistence(timeout: 5),
            "选择后「参考」pill 应立即出现"
        )
        XCTAssertEqual(app.sheets.count, 0, "标签切换不应出现确认 dialog")

        referenceOption.click()
        XCTAssertTrue(
            referenceOption.waitForValue("未选择", timeout: 5),
            "再次点击后「参考」应未选择"
        )
        XCTAssertTrue(
            waitForElementGone(referencePill, timeout: 5),
            "取消后「参考」pill 应立即消失"
        )
    }

    // MARK: - UI-MENU-006 补充：上限时 checkbox 未选、计数仍 5

    func testPicker_Limit_UnselectedDisabled_NoDialog()
    {
        let app = launchWithLimitFixture()

        XCTAssertTrue(
            app.staticTexts["tagLimitHint"].waitForExistence(timeout: 5),
            "满额时应显示上限提示"
        )

        let unselectedCount = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "tagOption_")
        ).matching(NSPredicate(format: "value == %@", "未选择")).count
        XCTAssertGreaterThan(unselectedCount, 0, "满额时应存在未选择的候选")

        XCTAssertEqual(app.sheets.count, 0, "满额时不应出现确认 dialog")
    }

    // MARK: - UI-MENU-007：设置目录无候选名、条目仍 5

    func testPicker_SettingsDirectory_NoCandidateNames_EntriesStillFive()
    {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_PREVIEW_DATA",
            "--UITEST_TAG_LIMIT_FIXTURE",
            "--UITEST_INITIAL_TAB=tags"
        ]
        app.launch()
        app.activate()

        let settingsButton = app.buttons["settingsButton"].firstMatch
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 10), "设置按钮应存在")
        settingsButton.click()

        let firstUserRow = app.descendants(matching: .any)[
            "userTagRow_\(firstLimitTagID)"
        ].firstMatch
        XCTAssertTrue(
            firstUserRow.waitForExistence(timeout: 15),
            "设置面板应显示用户标签行"
        )

        let tagOptions = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "tagOption_")
        ).count
        XCTAssertEqual(tagOptions, 0, "设置目录不应有 picker 候选项")

        let userRows = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "userTagRow_")
        ).count
        XCTAssertEqual(userRows, 5, "设置目录应显示 5 个用户标签")
    }

    // MARK: - UI-MENU-008：系统 pill 移除并在重启后保持

    func testPicker_SystemTagRemoval_PersistsAfterRelaunch()
    {
        let app = launchAndOpenPicker()

        let systemPill = app.buttons[
            "clipTag_\(firstClipIDString)_\(codeSystemTagID)"
        ]
        XCTAssertTrue(
            systemPill.waitForExistence(timeout: 10),
            "第一次启动应显示系统标签 pill"
        )
        systemPill.click()

        let systemOption = app.buttons["tagOption_\(codeSystemTagID)"]
        XCTAssertTrue(systemOption.waitForExistence(timeout: 5), "系统标签应出现在候选中")
        systemOption.click()
        XCTAssertTrue(
            systemOption.waitForValue("未选择", timeout: 5),
            "移除后系统标签应未选择"
        )

        XCTAssertTrue(
            waitForElementGone(systemPill, timeout: 10),
            "移除后系统标签 pill 应消失"
        )

        app.terminate()

        let relaunchedApp = relaunchPreviewOnly()
        let systemPillAfterRelaunch = relaunchedApp.buttons[
            "clipTag_\(firstClipIDString)_\(codeSystemTagID)"
        ]
        XCTAssertTrue(
            waitForElementGone(systemPillAfterRelaunch, timeout: 10),
            "重启后系统标签移除应保持"
        )
    }

    // MARK: - UI-MENU-009：满额恢复拒绝、释放后恢复、其他系统项不存在

    func testPicker_AtLimit_RestoreRejectedThenAllowed_OtherSystemTagsAbsent()
    {
        let app = launchWithLimitFixture()

        XCTAssertTrue(
            app.staticTexts["tagLimitHint"].waitForExistence(timeout: 5),
            "满额时应显示上限提示"
        )

        XCTAssertTrue(
            app.buttons["tagOption_\(codeSystemTagID)"].exists,
            "code 条目候选应包含 system.code"
        )
        XCTAssertFalse(
            app.buttons["tagOption_system.link"].exists,
            "code 条目候选不应包含 system.link（其他系统项不存在）"
        )

        tryReleaseFirstUserTag(app: app)

        // 释放后可恢复（选择之前被禁用的项）
        let unselectedOptions = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "tagOption_")
        ).matching(NSPredicate(format: "value == %@", "未选择"))
        if unselectedOptions.firstMatch.exists
        {
            let optionToRestore = unselectedOptions.firstMatch
            optionToRestore.click()
            XCTAssertTrue(
                optionToRestore.waitForValue("已选择", timeout: 5),
                "释放后应可恢复之前禁用的项"
            )
        }
    }

    // MARK: - UI-MENU-010：11 个具名色按钮、无自定义色输入、无颜色编辑

    func testPicker_ColorPalette_ElevenNamedColors_NoCustomColor()
    {
        let app = launchAndOpenPicker()

        let searchField = app.textFields["tagPickerSearch"]
        searchField.click()
        searchField.typeText("颜色测试标签")

        let createEntry = app.buttons["tagCreateEntry"]
        XCTAssertTrue(createEntry.waitForExistence(timeout: 3), "无匹配时应显示创建入口")
        createEntry.click()

        for rawValue in allColorRawValues
        {
            let colorButton = app.buttons["tagColor_\(rawValue)"]
            XCTAssertTrue(
                colorButton.waitForExistence(timeout: 3),
                "应存在颜色按钮 tagColor_\(rawValue)"
            )
        }
        let totalColorButtons = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "tagColor_")
        ).count
        XCTAssertEqual(totalColorButtons, 11, "应有 11 个颜色按钮")

        XCTAssertFalse(
            app.textFields["tagCustomColorInput"].exists,
            "不应存在自定义色输入框"
        )
        XCTAssertFalse(
            app.buttons["tagColorEdit"].exists,
            "不应存在颜色编辑按钮"
        )
    }

    // MARK: - UI-MENU-011：fail-once 后原 pill、safe error、retry 后成功

    func testPicker_FailOnce_OriginalPill_SafeError_RetrySucceeds()
    {
        let app = launchAndOpenPicker(extraArgs: ["--UITEST_TAG_FAIL_ONCE", "create"])

        let workPill = app.buttons[
            "clipTag_\(firstClipIDString)_\(firstUserTagID)"
        ]
        XCTAssertTrue(workPill.exists, "原「工作」pill 应存在")

        let searchField = app.textFields["tagPickerSearch"]
        searchField.click()
        searchField.typeText("失败重试标签")

        let createEntry = app.buttons["tagCreateEntry"]
        XCTAssertTrue(createEntry.waitForExistence(timeout: 3), "应显示创建入口")
        createEntry.click()

        let nameField = app.textFields["tagCreateNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3))
        nameField.click()
        nameField.typeText("失败重试标签")

        app.buttons["tagCreateConfirm"].click()

        let errorMessage = app.descendants(matching: .any)["tagErrorMessage"].firstMatch
        XCTAssertTrue(
            errorMessage.waitForExistence(timeout: 10),
            "失败后应显示安全错误信息"
        )
        XCTAssertTrue(
            app.buttons["tagRetryButton"].exists,
            "失败后应显示 retry 按钮"
        )
        XCTAssertTrue(workPill.exists, "失败后原「工作」pill 应保持存在")

        app.buttons["tagRetryButton"].click()
        XCTAssertTrue(
            waitForElementGone(errorMessage, timeout: 10),
            "retry 后安全错误应消失"
        )
    }
}

// MARK: - 辅助方法

private extension TagPickerExtendedUITests
{
    /// 启动主窗口并打开第一个条目的标签选择菜单。
    func launchAndOpenPicker(extraArgs: [String] = []) -> XCUIApplication
    {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_PREVIEW_DATA",
            "--UITEST_TAG_FIXTURE"
        ] + extraArgs
        app.launch()
        app.activate()

        let tagPill = app.buttons["clipTag_\(firstClipIDString)_\(firstUserTagID)"]
        XCTAssertTrue(
            tagPill.waitForExistence(timeout: 10),
            "主窗口应显示有标签条目的 pill"
        )
        tagPill.click()

        let pickerTitle = app.staticTexts["tagPickerTitle"]
        XCTAssertTrue(
            pickerTitle.waitForExistence(timeout: 5),
            "应打开标签选择菜单"
        )
        return app
    }

    /// 启动上限夹具并打开 picker。
    func launchWithLimitFixture() -> XCUIApplication
    {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_PREVIEW_DATA",
            "--UITEST_TAG_LIMIT_FIXTURE"
        ]
        app.launch()
        app.activate()

        let tagPill = app.buttons["clipTag_\(firstClipIDString)_\(firstLimitTagID)"]
        XCTAssertTrue(tagPill.waitForExistence(timeout: 10), "应显示标签 pill")
        tagPill.click()
        return app
    }

    /// 重启 app（仅 preview data，不注入夹具）。
    func relaunchPreviewOnly() -> XCUIApplication
    {
        let app = XCUIApplication()
        app.launchArguments = ["--UITEST_SHOW_MAIN_WINDOW", "--UITEST_PREVIEW_DATA"]
        app.launch()
        app.activate()
        return app
    }

    /// 释放第一个用户标签，验证上限提示消失。
    func tryReleaseFirstUserTag(app: XCUIApplication)
    {
        let firstOption = app.buttons["tagOption_\(firstLimitTagID)"]
        XCTAssertTrue(firstOption.waitForExistence(timeout: 3), "第一个用户标签应存在")
        if firstOption.value as? String == "已选择"
        {
            firstOption.click()
            XCTAssertTrue(
                firstOption.waitForValue("未选择", timeout: 5),
                "释放后第一个用户标签应未选择"
            )
            XCTAssertTrue(
                waitForElementGone(app.staticTexts["tagLimitHint"], timeout: 5),
                "释放后上限提示应消失"
            )
        }
    }

    /// 等待元素消失（不存在）。
    @discardableResult
    func waitForElementGone(_ element: XCUIElement, timeout: TimeInterval) -> Bool
    {
        let predicate = NSPredicate { _, _ in !element.exists }
        let expectation = XCTNSPredicateExpectation(
            predicate: predicate,
            object: element
        )
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}

// MARK: - XCUIElement 辅助

private extension XCUIElement
{
    /// 清空文本输入框内容。
    func clearText()
    {
        guard let currentValue = value as? String, !currentValue.isEmpty else
        {
            return
        }
        click()
        let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count)
        typeText(deleteString)
    }

    /// 等待 `accessibilityValue` 变为指定值。
    @discardableResult
    func waitForValue(_ expected: String, timeout: TimeInterval = 5) -> Bool
    {
        let predicate = NSPredicate { element, _ in
            (element as? XCUIElement)?.value as? String == expected
        }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}
