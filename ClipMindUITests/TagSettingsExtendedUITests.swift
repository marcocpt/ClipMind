import AppKit
import XCTest

/// F1.14 Phase 5 SET 扩展用例：跨入口传播、retry 成功、Escape 键盘操作。
///
/// 从 `TagSettingsUITests` 拆分以控制文件长度。覆盖：
/// - 用户标签有 rename/delete button（SET-001 互补）
/// - 系统重名拒绝（SET-005 补充）
/// - retry 成功（SET-007 补充）
/// - Escape 关闭 dialog（SET-008 补充）
/// - 跨入口名称更新与顺序不变（SET-006 补充）
/// - 跨入口删除验证（SET-003 补充）
final class TagSettingsExtendedUITests: XCTestCase
{
    // MARK: - 稳定夹具常量

    /// 第一个用户标签 ID（标准夹具 "工作"）。
    private let firstUserTagID = "user.00000000-0000-4000-8000-000000000101"

    /// 第二个用户标签 ID（标准夹具 "参考"）。
    private let secondUserTagID = "user.00000000-0000-4000-8000-000000000102"

    /// `previewClips[0]` 的稳定 UUID（code 类型，关联「工作」和 system.code）。
    private let firstClipIDString = "00000000-0000-4000-8000-000000000001"

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

    // MARK: - SET-001 补充：用户标签有 rename/delete button

    /// 用户标签行同时有重命名和删除按钮（与系统标签只读互补）。
    func testSettings_UserTagsHaveRenameAndDeleteButtons()
    {
        let app = launchSettings(extraArgs: [])

        let renameButton = app.buttons["renameTag_\(firstUserTagID)"]
        let deleteButton = app.buttons["deleteTag_\(firstUserTagID)"]
        XCTAssertTrue(
            renameButton.waitForExistence(timeout: 10),
            "用户标签应有重命名按钮"
        )
        XCTAssertTrue(
            deleteButton.exists,
            "用户标签应有删除按钮"
        )
    }

    // MARK: - SET-005 补充：系统重名拒绝

    /// 重命名为系统标签名（"CODE"）在进入确认前拒绝，显示校验错误。
    func testSettings_RenameSystemTagName_RejectedBeforeConfirm()
    {
        let app = launchSettings(extraArgs: [])

        let renameButton = app.buttons["renameTag_\(firstUserTagID)"]
        XCTAssertTrue(renameButton.waitForExistence(timeout: 10))
        renameButton.click()

        let nameField = app.textFields["renameTagField_\(firstUserTagID)"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3))
        nameField.click()
        clearText(nameField)
        nameField.typeText("CODE")

        app.buttons["submitRenameTag_\(firstUserTagID)"].click()

        let validationError = app.descendants(matching: .any)[
            "renameValidationError_\(firstUserTagID)"
        ].firstMatch
        XCTAssertTrue(
            validationError.waitForExistence(timeout: 3),
            "系统重名应显示校验错误"
        )
        XCTAssertFalse(
            app.sheets.buttons["重命名"].exists,
            "系统重名不应进入确认 dialog"
        )
    }

    // MARK: - SET-007 补充：retry 成功

    /// 重命名 fail-once 后 retry 成功：错误消失，标签行保持存在（stable ID 不变）。
    func testSettings_RenameFailure_RetrySucceeds()
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

        let confirmButton = app.sheets.buttons["重命名"]
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 5))
        confirmButton.click()

        let retryButton = app.buttons["settingsTagRetryButton"]
        XCTAssertTrue(
            retryButton.waitForExistence(timeout: 10),
            "失败后应显示 retry 按钮"
        )

        retryButton.click()
        XCTAssertTrue(
            waitForErrorMessageGone(app: app, timeout: 10),
            "retry 后错误信息应消失"
        )

        let userRow = app.descendants(matching: .any)["userTagRow_\(firstUserTagID)"].firstMatch
        XCTAssertTrue(
            userRow.exists,
            "retry 成功后标签行应存在"
        )
    }

    /// 删除 fail-once 后 retry 成功：错误消失，标签行消失。
    func testSettings_DeleteFailure_RetrySucceeds()
    {
        let app = launchSettings(extraArgs: ["--UITEST_TAG_FAIL_ONCE", "delete"])

        let deleteButton = app.buttons["deleteTag_\(firstUserTagID)"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 10))
        deleteButton.click()

        let confirmButton = app.sheets.buttons["删除"]
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 5))
        confirmButton.click()

        let retryButton = app.buttons["settingsTagRetryButton"]
        XCTAssertTrue(
            retryButton.waitForExistence(timeout: 10),
            "失败后应显示 retry 按钮"
        )

        retryButton.click()
        XCTAssertTrue(
            waitForErrorMessageGone(app: app, timeout: 10),
            "retry 后错误信息应消失"
        )

        let userRow = app.descendants(matching: .any)["userTagRow_\(firstUserTagID)"].firstMatch
        XCTAssertTrue(
            waitForElementGone(userRow, timeout: 10),
            "retry 成功后标签行应消失"
        )
    }

    // MARK: - SET-008 补充：Escape 关闭 dialog

    /// Escape 键取消重命名确认 dialog，回到原状。
    func testSettings_Dialog_EscapeCancelsRename()
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

        let confirmButton = app.sheets.buttons["重命名"]
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 5))

        app.typeKey(XCUIKeyboardKey.escape.rawValue)

        XCTAssertTrue(
            waitForElementGone(confirmButton, timeout: 5),
            "Escape 后确认 dialog 应消失"
        )

        let userRow = app.descendants(matching: .any)["userTagRow_\(firstUserTagID)"].firstMatch
        XCTAssertTrue(
            userRow.exists,
            "Escape 取消后标签行应仍存在"
        )
    }

    /// Escape 键取消删除确认 dialog，回到原状。
    func testSettings_Dialog_EscapeCancelsDelete()
    {
        let app = launchSettings(extraArgs: [])

        let deleteButton = app.buttons["deleteTag_\(firstUserTagID)"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 10))
        deleteButton.click()

        let confirmButton = app.sheets.buttons["删除"]
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 5))

        app.typeKey(XCUIKeyboardKey.escape.rawValue)

        XCTAssertTrue(
            waitForElementGone(confirmButton, timeout: 5),
            "Escape 后确认 dialog 应消失"
        )

        let userRow = app.descendants(matching: .any)["userTagRow_\(firstUserTagID)"].firstMatch
        XCTAssertTrue(
            userRow.exists,
            "Escape 取消后标签行应仍存在"
        )
    }

    // MARK: - SET-006 补充：跨入口名称更新与顺序不变

    /// 重命名后 stable ID 保持、名称跨入口（设置 + 主窗口 + picker）更新、顺序不变。
    func testSettings_RenamePropagatesToAllEntries_OrderPreserved()
    {
        let app = launchSettings(extraArgs: [])

        let firstRow = app.descendants(matching: .any)["userTagRow_\(firstUserTagID)"].firstMatch
        let secondRow = app.descendants(matching: .any)["userTagRow_\(secondUserTagID)"].firstMatch
        XCTAssertTrue(firstRow.waitForExistence(timeout: 10))
        XCTAssertTrue(secondRow.exists)
        XCTAssertLessThan(
            firstRow.frame.minY,
            secondRow.frame.minY,
            "重命名前「工作」行应在「参考」行之前"
        )

        performRename(app: app, newName: "工作已重命名")

        // 设置入口：stable ID 保持、顺序不变
        XCTAssertTrue(
            firstRow.waitForExistence(timeout: 5),
            "重命名后设置入口 stable ID 行应存在"
        )
        XCTAssertLessThan(
            firstRow.frame.minY,
            secondRow.frame.minY,
            "重命名后顺序应保持不变"
        )

        // 主窗口入口：pill 仍存在（stable ID 不变）
        let mainWindowPill = app.buttons[
            "clipTag_\(firstClipIDString)_\(firstUserTagID)"
        ]
        XCTAssertTrue(
            mainWindowPill.waitForExistence(timeout: 10),
            "重命名后主窗口 pill 应仍存在（stable ID 不变）"
        )

        // picker 入口：重启后从主窗口打开 picker，候选仍存在
        app.terminate()
        let relaunchedApp = relaunchAndOpenPicker(
            via: "clipTag_\(firstClipIDString)_\(firstUserTagID)"
        )
        XCTAssertTrue(
            relaunchedApp.buttons["tagOption_\(firstUserTagID)"].waitForExistence(timeout: 5),
            "重命名后 picker 候选应仍存在（stable ID 不变）"
        )
    }

    // MARK: - SET-003 补充：跨入口删除验证

    /// 删除确认后标签从设置目录、主窗口 pill 和 picker 候选中消失。
    func testSettings_DeleteConfirmation_TagRemovedFromAllEntries()
    {
        let app = launchSettings(extraArgs: [])

        let deleteButton = app.buttons["deleteTag_\(firstUserTagID)"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 10))
        deleteButton.click()

        let confirmButton = app.sheets.buttons["删除"]
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 5))
        confirmButton.click()

        // 设置入口：行消失
        let settingsRow = app.descendants(matching: .any)[
            "userTagRow_\(firstUserTagID)"
        ].firstMatch
        XCTAssertTrue(
            waitForElementGone(settingsRow, timeout: 10),
            "删除后设置入口行应消失"
        )

        // 主窗口入口：pill 消失
        let mainWindowPill = app.buttons[
            "clipTag_\(firstClipIDString)_\(firstUserTagID)"
        ]
        XCTAssertTrue(
            waitForElementGone(mainWindowPill, timeout: 10),
            "删除后主窗口 pill 应消失"
        )

        // picker 入口：重启后从主窗口打开 picker，候选消失
        app.terminate()
        let relaunchedApp = relaunchAndOpenPicker(
            via: "clipTag_\(firstClipIDString)_\(codeSystemTagID)"
        )
        XCTAssertTrue(
            waitForElementGone(
                relaunchedApp.buttons["tagOption_\(firstUserTagID)"],
                timeout: 5
            ),
            "删除后 picker 候选应消失"
        )
    }
}

// MARK: - 辅助方法

private extension TagSettingsExtendedUITests
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

        let settingsButton = app.buttons["settingsButton"].firstMatch
        XCTAssertTrue(
            settingsButton.waitForExistence(timeout: 10),
            "设置按钮应存在"
        )
        settingsButton.click()

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

    /// 执行重命名操作：点击重命名 → 输入新名称 → 提交 → 确认。
    func performRename(app: XCUIApplication, newName: String)
    {
        let renameButton = app.buttons["renameTag_\(firstUserTagID)"]
        renameButton.click()

        let nameField = app.textFields["renameTagField_\(firstUserTagID)"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3))
        nameField.click()
        clearText(nameField)
        nameField.typeText(newName)

        app.buttons["submitRenameTag_\(firstUserTagID)"].click()

        let confirmButton = app.sheets.buttons["重命名"]
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 5))
        confirmButton.click()
    }

    /// 重启 app 并从主窗口打开 picker。
    @discardableResult
    func relaunchAndOpenPicker(via pillIdentifier: String) -> XCUIApplication
    {
        let app = XCUIApplication()
        app.launchArguments = ["--UITEST_SHOW_MAIN_WINDOW", "--UITEST_PREVIEW_DATA"]
        app.launch()
        app.activate()

        let pill = app.buttons[pillIdentifier]
        XCTAssertTrue(
            pill.waitForExistence(timeout: 10),
            "重启后 pill 应存在"
        )
        pill.click()
        return app
    }

    /// 等待错误信息元素消失。
    @discardableResult
    func waitForErrorMessageGone(app: XCUIApplication, timeout: TimeInterval) -> Bool
    {
        let errorMessage = app.descendants(matching: .any)["settingsTagErrorMessage"].firstMatch
        return waitForElementGone(errorMessage, timeout: timeout)
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
