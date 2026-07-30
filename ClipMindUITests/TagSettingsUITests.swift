import AppKit
import XCTest

/// F1.14 Phase 4 任务 4：设置管理 UI Smoke。
///
/// 通过 `--UITEST_INITIAL_TAB=tags` 驱动真实 Settings window，覆盖 SET-001～008 当前能力：
/// - SET-001：系统标签只读（无可点击的重命名/删除按钮）
/// - SET-002：用户标签 rename 两阶段确认
/// - SET-003：用户标签 delete 二次确认
/// - SET-004：取消重命名/删除保持原状
/// - SET-005：空白/重名拒绝
/// - SET-006：stable ID 跨入口传播（标签 ID 不变）
/// - SET-007：失败回滚与 retry（使用 `--UITEST_TAG_FAIL_ONCE` 夹具）
/// - SET-008：dialog 焦点恢复（通过 alert 可操作验证）
///
/// 测试只读取可访问性树，不读取数据库或 `TagStore.snapshot`。
/// 使用 `--UITEST_TAG_FIXTURE` 注入 2 个用户标签（"工作"、"参考"）。
final class TagSettingsUITests: XCTestCase
{
    // MARK: - 稳定夹具常量

    /// 第一个用户标签 ID（标准夹具 "工作"）。
    private let firstUserTagID = "user.00000000-0000-4000-8000-000000000101"

    /// code 类型系统标签 ID。
    private let codeSystemTagID = "system.code"

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

    // MARK: - SET-001：系统标签只读

    /// 系统标签行存在但无可点击的重命名/删除按钮。
    func testSettings_SystemTagsReadOnly_NoRenameOrDeleteButtons()
    {
        let app = launchSettings(extraArgs: [])

        // 系统标签行存在
        let systemRow = app.descendants(matching: .any)["systemTagRow_\(codeSystemTagID)"].firstMatch
        XCTAssertTrue(
            systemRow.waitForExistence(timeout: 10),
            "系统标签行应存在"
        )

        // 系统标签不应有重命名或删除按钮
        let renameButton = app.buttons["renameTag_\(codeSystemTagID)"]
        let deleteButton = app.buttons["deleteTag_\(codeSystemTagID)"]
        XCTAssertFalse(renameButton.exists, "系统标签不应有重命名按钮")
        XCTAssertFalse(deleteButton.exists, "系统标签不应有删除按钮")
    }

    // MARK: - SET-002：用户标签 rename 两阶段确认

    /// 用户标签重命名：点击重命名 → 编辑 → 提交 → 独立确认 alert → 确认后生效。
    func testSettings_UserTagRename_TwoPhaseConfirmation()
    {
        let app = launchSettings(extraArgs: [])

        let renameButton = app.buttons["renameTag_\(firstUserTagID)"]
        XCTAssertTrue(renameButton.waitForExistence(timeout: 10), "重命名按钮应存在")
        renameButton.click()

        // 编辑行出现
        let nameField = app.textFields["renameTagField_\(firstUserTagID)"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3), "编辑行应显示名称输入框")

        // 清空并输入新名称
        nameField.click()
        clearText(nameField)
        nameField.typeText("工作已重命名")

        // 提交进入确认阶段
        let submitButton = app.buttons["submitRenameTag_\(firstUserTagID)"]
        XCTAssertTrue(submitButton.exists, "提交按钮应存在")
        submitButton.click()

        // 独立确认 alert 出现，包含"重命名"按钮
        let confirmButton = app.buttons["重命名"]
        XCTAssertTrue(
            confirmButton.waitForExistence(timeout: 5),
            "应弹独立确认 dialog，包含「重命名」按钮"
        )

        // 确认后 alert 关闭
        confirmButton.click()

        // 验证：编辑 UI 消失，行仍存在（stable ID 不变）
        XCTAssertFalse(
            app.buttons["submitRenameTag_\(firstUserTagID)"].exists,
            "确认后编辑 UI 应消失"
        )
        let userRow = app.descendants(matching: .any)["userTagRow_\(firstUserTagID)"].firstMatch
        XCTAssertTrue(
            userRow.waitForExistence(timeout: 5),
            "重命名后行仍存在（stable ID 不变）"
        )
    }

    // MARK: - SET-003：用户标签 delete 二次确认

    /// 用户标签删除：点击删除 → 独立确认 alert → 确认后从目录移除。
    func testSettings_UserTagDelete_TwoPhaseConfirmation()
    {
        let app = launchSettings(extraArgs: [])

        let deleteButton = app.buttons["deleteTag_\(firstUserTagID)"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 10), "删除按钮应存在")
        deleteButton.click()

        // 独立确认 alert 出现，包含"删除"按钮
        let confirmButton = app.buttons["删除"]
        XCTAssertTrue(
            confirmButton.waitForExistence(timeout: 5),
            "应弹独立确认 dialog，包含「删除」按钮"
        )

        // 确认删除
        confirmButton.click()

        // 验证：行消失
        let userRow = app.descendants(matching: .any)["userTagRow_\(firstUserTagID)"].firstMatch
        let predicate = NSPredicate { _, _ in !userRow.exists }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: userRow)
        let result = XCTWaiter().wait(for: [expectation], timeout: 10)
        XCTAssertTrue(
            result == .completed,
            "删除后行应消失"
        )
    }

    // MARK: - SET-004：取消重命名/删除保持原状

    /// 取消重命名：从编辑阶段或确认阶段取消，回到原状，未发生 mutation。
    func testSettings_CancelRename_KeepsOriginalState()
    {
        let app = launchSettings(extraArgs: [])

        let renameButton = app.buttons["renameTag_\(firstUserTagID)"]
        XCTAssertTrue(renameButton.waitForExistence(timeout: 10))
        renameButton.click()

        // 取消编辑
        let cancelButton = app.buttons["cancelRenameTag_\(firstUserTagID)"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 3), "取消按钮应存在")
        cancelButton.click()

        // 验证：编辑 UI 消失，行仍存在
        XCTAssertFalse(
            app.buttons["cancelRenameTag_\(firstUserTagID)"].exists,
            "取消后编辑 UI 应消失"
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["userTagRow_\(firstUserTagID)"].firstMatch.exists,
            "取消后行仍存在"
        )
    }

    /// 取消删除：从确认 alert 取消，回到原状。
    func testSettings_CancelDelete_KeepsOriginalState()
    {
        let app = launchSettings(extraArgs: [])

        let deleteButton = app.buttons["deleteTag_\(firstUserTagID)"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 10))
        deleteButton.click()

        // 取消确认
        let cancelButton = app.buttons["取消"]
        XCTAssertTrue(
            cancelButton.waitForExistence(timeout: 5),
            "确认 dialog 应包含「取消」按钮"
        )
        cancelButton.click()

        // 验证：行仍存在
        let userRow = app.descendants(matching: .any)["userTagRow_\(firstUserTagID)"].firstMatch
        XCTAssertTrue(
            userRow.waitForExistence(timeout: 5),
            "取消删除后行仍存在"
        )
    }

    // MARK: - SET-005：空白/重名拒绝

    /// 空白名称在进入确认前拒绝，显示校验错误。
    func testSettings_RenameEmptyName_RejectedBeforeConfirm()
    {
        let app = launchSettings(extraArgs: [])

        let renameButton = app.buttons["renameTag_\(firstUserTagID)"]
        XCTAssertTrue(renameButton.waitForExistence(timeout: 10))
        renameButton.click()

        let nameField = app.textFields["renameTagField_\(firstUserTagID)"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3))
        nameField.click()
        clearText(nameField)
        nameField.typeText("   ")

        app.buttons["submitRenameTag_\(firstUserTagID)"].click()

        // 应停留在编辑态并显示校验错误
        let validationError = app.descendants(matching: .any)[
            "renameValidationError_\(firstUserTagID)"
        ].firstMatch
        XCTAssertTrue(
            validationError.waitForExistence(timeout: 3),
            "空白名称应显示校验错误"
        )
        XCTAssertFalse(
            app.buttons["重命名"].exists,
            "空白名称不应进入确认 dialog"
        )
    }

    /// 大小写重名在进入确认前拒绝。
    func testSettings_RenameDuplicateName_RejectedBeforeConfirm()
    {
        let app = launchSettings(extraArgs: [])

        let renameButton = app.buttons["renameTag_\(firstUserTagID)"]
        XCTAssertTrue(renameButton.waitForExistence(timeout: 10))
        renameButton.click()

        let nameField = app.textFields["renameTagField_\(firstUserTagID)"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3))
        nameField.click()
        clearText(nameField)
        // 第二个标签名为"参考"，输入大写变体触发重名
        nameField.typeText("参考")

        app.buttons["submitRenameTag_\(firstUserTagID)"].click()

        let validationError = app.descendants(matching: .any)[
            "renameValidationError_\(firstUserTagID)"
        ].firstMatch
        XCTAssertTrue(
            validationError.waitForExistence(timeout: 3),
            "重名应显示校验错误"
        )
        XCTAssertFalse(
            app.buttons["重命名"].exists,
            "重名不应进入确认 dialog"
        )
    }

    // MARK: - SET-006：stable ID 跨入口传播

    /// 重命名后标签 ID 不变，同一行 identifier 仍可定位。
    /// 跨入口传播（主窗口/菜单栏/设置）由 TagStore.snapshot 统一驱动，
    /// 此处验证设置页通过 stable ID 仍能定位到重命名后的行。
    func testSettings_RenamePreservesStableID()
    {
        let app = launchSettings(extraArgs: [])

        let renameButton = app.buttons["renameTag_\(firstUserTagID)"]
        XCTAssertTrue(renameButton.waitForExistence(timeout: 10))
        renameButton.click()

        let nameField = app.textFields["renameTagField_\(firstUserTagID)"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3))
        nameField.click()
        clearText(nameField)
        nameField.typeText("工作已重命名")

        app.buttons["submitRenameTag_\(firstUserTagID)"].click()

        let confirmButton = app.buttons["重命名"]
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 5))
        confirmButton.click()

        // 重命名后通过同一 stable ID 仍能定位行
        let userRow = app.descendants(matching: .any)["userTagRow_\(firstUserTagID)"].firstMatch
        XCTAssertTrue(
            userRow.waitForExistence(timeout: 10),
            "重命名后通过 stable ID 仍能定位行"
        )
    }

    // MARK: - SET-007：失败回滚与 retry

    /// 重命名失败显示错误信息和 retry 按钮。
    /// 需要 `--UITEST_TAG_FAIL_ONCE rename` 夹具（仅 CLIPMIND_DEV 构建生效）。
    func testSettings_RenameFailure_ShowsRetryButton()
    {
        let app = launchSettings(extraArgs: ["--UITEST_TAG_FAIL_ONCE", "rename"])

        let renameButton = app.buttons["renameTag_\(firstUserTagID)"]
        XCTAssertTrue(renameButton.waitForExistence(timeout: 10))
        renameButton.click()

        let nameField = app.textFields["renameTagField_\(firstUserTagID)"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3))
        nameField.click()
        clearText(nameField)
        nameField.typeText("工作已重命名")

        app.buttons["submitRenameTag_\(firstUserTagID)"].click()

        let confirmButton = app.buttons["重命名"]
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 5))
        confirmButton.click()

        // 失败后显示 retry 按钮和错误信息
        let retryButton = app.buttons["settingsTagRetryButton"]
        XCTAssertTrue(
            retryButton.waitForExistence(timeout: 10),
            "失败后应显示 retry 按钮"
        )
        let errorMessage = app.descendants(matching: .any)["settingsTagErrorMessage"].firstMatch
        XCTAssertTrue(
            errorMessage.waitForExistence(timeout: 3),
            "失败后应显示错误信息"
        )

        // 原标签仍存在（snapshot 保持最近成功状态）
        let userRow = app.descendants(matching: .any)["userTagRow_\(firstUserTagID)"].firstMatch
        XCTAssertTrue(
            userRow.exists,
            "失败后原标签应保持存在"
        )
    }

    /// 删除失败显示错误信息和 retry 按钮。
    /// 需要 `--UITEST_TAG_FAIL_ONCE delete` 夹具（仅 CLIPMIND_DEV 构建生效）。
    func testSettings_DeleteFailure_ShowsRetryButton()
    {
        let app = launchSettings(extraArgs: ["--UITEST_TAG_FAIL_ONCE", "delete"])

        let deleteButton = app.buttons["deleteTag_\(firstUserTagID)"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 10))
        deleteButton.click()

        let confirmButton = app.buttons["删除"]
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 5))
        confirmButton.click()

        // 失败后显示 retry 按钮
        let retryButton = app.buttons["settingsTagRetryButton"]
        XCTAssertTrue(
            retryButton.waitForExistence(timeout: 10),
            "失败后应显示 retry 按钮"
        )

        // 原标签仍存在（snapshot 保持最近成功状态）
        let userRow = app.descendants(matching: .any)["userTagRow_\(firstUserTagID)"].firstMatch
        XCTAssertTrue(
            userRow.exists,
            "删除失败后原标签应保持存在"
        )
    }

    // MARK: - SET-008：dialog 可键盘操作

    /// 确认 dialog 出现后，取消按钮可通过点击触发，验证 dialog 可交互。
    /// 完整键盘焦点恢复验证由辅助功能测试覆盖，此处验证 dialog 基本可操作性。
    func testSettings_RenameConfirmDialog_IsInteractive()
    {
        let app = launchSettings(extraArgs: [])

        let renameButton = app.buttons["renameTag_\(firstUserTagID)"]
        XCTAssertTrue(renameButton.waitForExistence(timeout: 10))
        renameButton.click()

        let nameField = app.textFields["renameTagField_\(firstUserTagID)"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3))
        nameField.click()
        clearText(nameField)
        nameField.typeText("工作已重命名")

        app.buttons["submitRenameTag_\(firstUserTagID)"].click()

        // 验证 dialog 按钮可交互
        let cancelButton = app.buttons["取消"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 5))
        let confirmButton = app.buttons["重命名"]
        XCTAssertTrue(confirmButton.exists, "确认按钮应存在")

        // 取消 dialog
        cancelButton.click()

        // 验证取消后回到原状
        let userRow = app.descendants(matching: .any)["userTagRow_\(firstUserTagID)"].firstMatch
        XCTAssertTrue(
            userRow.waitForExistence(timeout: 5),
            "取消 dialog 后行仍存在"
        )
    }
}

// MARK: - 辅助方法

private extension TagSettingsUITests
{
    /// 启动 App 并打开设置面板（tags 标签已通过启动参数定位）。
    func launchSettings(extraArgs: [String]) -> XCUIApplication
    {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_PREVIEW_DATA",
            "--UITEST_TAG_FIXTURE",
            "--UITEST_INITIAL_TAB=tags"
        ] + extraArgs
        app.launch()
        app.activate()

        // 点击设置按钮打开独立设置窗口
        let settingsButton = app.buttons["settingsButton"].firstMatch
        XCTAssertTrue(
            settingsButton.waitForExistence(timeout: 10),
            "设置按钮应存在"
        )
        settingsButton.click()

        // 等待 tags 标签内容加载：用户标签行出现
        let userRow = app.descendants(matching: .any)[
            "userTagRow_\(firstUserTagID)"
        ].firstMatch
        XCTAssertTrue(
            userRow.waitForExistence(timeout: 15),
            "设置面板 tags 标签应显示用户标签行"
        )

        return app
    }

    /// 清空文本输入框内容。
    func clearText(_ field: XCUIElement)
    {
        guard let currentValue = field.value as? String, !currentValue.isEmpty else
        {
            return
        }
        field.click()
        let deleteString = String(
            repeating: XCUIKeyboardKey.delete.rawValue,
            count: currentValue.count
        )
        field.typeText(deleteString)
    }
}
