import AppKit
import XCTest

/// F1.14 Phase 2 任务 6：标签选择菜单 UI Smoke。
///
/// 验证 `TagPickerView` 的搜索、多选、创建、上限、系统标签移除/恢复和持久化重启。
/// 覆盖 UI-MENU-001～011 的当前 Phase 可通过能力。
final class TagPickerUITests: XCTestCase
{
    // MARK: - 稳定夹具常量

    /// `previewClips[0]` 的稳定 UUID（code 类型）。
    private let firstClipIDString = "00000000-0000-4000-8000-000000000001"
    /// `previewClips[1]` 的稳定 UUID（link 类型）。
    private let secondClipIDString = "00000000-0000-4000-8000-000000000002"
    /// 第一个用户标签 ID（标准夹具 "工作"）。
    private let firstUserTagID = "user.00000000-0000-4000-8000-000000000101"
    /// 第二个用户标签 ID（标准夹具 "参考"）。
    private let secondUserTagID = "user.00000000-0000-4000-8000-000000000102"
    /// code 类型系统标签 ID。
    private let codeSystemTagID = "system.code"
    /// 上限夹具第一个用户标签 ID（"标签1"）。
    private let firstLimitTagID = "user.00000000-0000-4000-8000-000000000201"

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

    // MARK: - 辅助方法

    /// 启动主窗口并打开第一个条目的标签选择菜单。
    private func launchAndOpenPicker(extraArgs: [String] = []) -> XCUIApplication
    {
        let app = XCUIApplication()
        app.launchArguments = ["--UITEST_SHOW_MAIN_WINDOW", "--UITEST_TAG_FIXTURE"] + extraArgs
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

    // MARK: - 搜索

    /// UI-MENU-002：搜索过滤候选标签。
    func testPicker_Search_FiltersCandidates()
    {
        let app = launchAndOpenPicker()

        let searchField = app.textFields["tagPickerSearch"]
        XCTAssertTrue(searchField.exists, "搜索框应存在")

        // 搜索「工作」应只显示匹配项
        searchField.click()
        searchField.typeText("工作")

        let workOption = app.buttons["tagOption_\(firstUserTagID)"]
        let referenceOption = app.buttons["tagOption_\(secondUserTagID)"]

        XCTAssertTrue(
            workOption.waitForExistence(timeout: 3),
            "搜索「工作」应显示匹配的标签"
        )
        XCTAssertFalse(
            referenceOption.exists,
            "搜索「工作」不应显示不匹配的标签"
        )

        // 清空搜索应恢复全部候选
        searchField.clearText()
        XCTAssertTrue(
            referenceOption.waitForExistence(timeout: 3),
            "清空搜索应恢复全部候选标签"
        )
    }

    // MARK: - 多选

    /// UI-MENU-004：切换标签选择状态。
    func testPicker_Toggle_SelectAndDeselect()
    {
        let app = launchAndOpenPicker()

        let referenceOption = app.buttons["tagOption_\(secondUserTagID)"]
        XCTAssertTrue(referenceOption.waitForExistence(timeout: 3))

        // 「参考」标签初始未选择（previewClips[0] 只有「工作」和系统标签）
        XCTAssertEqual(
            referenceOption.value as? String,
            "未选择",
            "「参考」标签初始应未选择"
        )

        // 点击选择，等待异步排空完成
        referenceOption.click()
        XCTAssertTrue(
            referenceOption.waitForValue("已选择", timeout: 5),
            "点击后「参考」标签应已选择"
        )

        // 再次点击取消
        referenceOption.click()
        XCTAssertTrue(
            referenceOption.waitForValue("未选择", timeout: 5),
            "再次点击后「参考」标签应未选择"
        )
    }

    // MARK: - 创建

    /// UI-MENU-006：无匹配时创建新标签。
    func testPicker_Create_NewTag()
    {
        let app = launchAndOpenPicker()

        let searchField = app.textFields["tagPickerSearch"]
        searchField.click()
        searchField.typeText("新标签")

        let createEntry = app.buttons["tagCreateEntry"]
        XCTAssertTrue(
            createEntry.waitForExistence(timeout: 3),
            "无匹配时应显示创建入口"
        )
        createEntry.click()

        let nameField = app.textFields["tagCreateNameField"]
        XCTAssertTrue(
            nameField.waitForExistence(timeout: 3),
            "创建模式应显示名称输入框"
        )
        nameField.click()
        nameField.typeText("新标签")

        let confirmButton = app.buttons["tagCreateConfirm"]
        XCTAssertTrue(confirmButton.exists, "创建确认按钮应存在")
        confirmButton.click()

        // 创建成功后应回到浏览状态
        let pickerTitle = app.staticTexts["tagPickerTitle"]
        XCTAssertTrue(
            pickerTitle.waitForExistence(timeout: 3),
            "创建成功后应回到浏览状态"
        )
    }

    // MARK: - 上限

    /// UI-MENU-009：5 个标签上限。
    func testPicker_Limit_CannotAddSixth()
    {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_TAG_LIMIT_FIXTURE"
        ]
        app.launch()
        app.activate()

        // previewClips[0] 有 1 个系统标签 + 4 个用户标签 = 5 个（已达上限）
        // 第 5 个用户标签创建失败（上限 5 含系统标签）
        let tagPill = app.buttons["clipTag_\(firstClipIDString)_\(firstLimitTagID)"]
        XCTAssertTrue(
            tagPill.waitForExistence(timeout: 10),
            "应显示标签 pill"
        )
        tagPill.click()

        let limitHint = app.staticTexts["tagLimitHint"]
        XCTAssertTrue(
            limitHint.waitForExistence(timeout: 5),
            "满额时应显示上限提示"
        )
    }

    // MARK: - 系统标签移除/恢复

    /// UI-MENU-010：系统标签移除后仍在候选中且未勾选，可恢复。
    func testPicker_SystemTag_RemoveAndRestore()
    {
        let app = launchAndOpenPicker()

        let systemTagOption = app.buttons["tagOption_\(codeSystemTagID)"]
        XCTAssertTrue(
            systemTagOption.waitForExistence(timeout: 3),
            "系统标签应出现在候选中"
        )

        // 系统标签初始已选择
        XCTAssertEqual(
            systemTagOption.value as? String,
            "已选择",
            "系统标签初始应已选择"
        )

        // 点击移除，等待异步排空完成
        systemTagOption.click()
        XCTAssertTrue(
            systemTagOption.waitForValue("未选择", timeout: 5),
            "移除后系统标签应未选择"
        )

        // 再次点击恢复
        systemTagOption.click()
        XCTAssertTrue(
            systemTagOption.waitForValue("已选择", timeout: 5),
            "恢复后系统标签应已选择"
        )
    }

    // MARK: - 持久化重启

    /// UI-MENU-011：标签关联在应用重启后保持。
    ///
    /// 第一次启动注入夹具（「工作」关联到 `previewClips[0]`，「参考」关联到 `previewClips[1]`），
    /// 第二次启动不注入夹具，验证标签关联从第一次启动持久化到第二次。
    func testPicker_Persistence_TagsSurviveRelaunch()
    {
        // 第一次启动：注入夹具
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_TAG_FIXTURE"
        ]
        app.launch()
        app.activate()

        let workPill = app.buttons["clipTag_\(firstClipIDString)_\(firstUserTagID)"]
        XCTAssertTrue(
            workPill.waitForExistence(timeout: 10),
            "第一次启动应显示「工作」标签"
        )

        let referencePill = app.buttons["clipTag_\(secondClipIDString)_\(secondUserTagID)"]
        XCTAssertTrue(
            referencePill.waitForExistence(timeout: 5),
            "第一次启动应在第二条目显示「参考」标签"
        )

        app.terminate()

        // 第二次启动：不注入夹具，验证标签持久化
        // previewClips 已在第一次启动时写入 DB，不传 --UITEST_TAG_FIXTURE 避免重复注入
        app.launchArguments = ["--UITEST_SHOW_MAIN_WINDOW"]
        app.launch()
        app.activate()

        let workPillAfterRelaunch = app.buttons[
            "clipTag_\(firstClipIDString)_\(firstUserTagID)"
        ]
        XCTAssertTrue(
            workPillAfterRelaunch.waitForExistence(timeout: 10),
            "重启后「工作」标签应持久化"
        )

        let referencePillAfterRelaunch = app.buttons[
            "clipTag_\(secondClipIDString)_\(secondUserTagID)"
        ]
        XCTAssertTrue(
            referencePillAfterRelaunch.waitForExistence(timeout: 5),
            "重启后「参考」标签应持久化"
        )
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
    ///
    /// `TagStore.perform` 是异步排空，click 后立即读取 value 可能仍是旧值。
    /// 用 `NSPredicate` 轮询直到 value 匹配或超时。
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
