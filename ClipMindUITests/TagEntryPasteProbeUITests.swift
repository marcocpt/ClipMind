import AppKit
import XCTest

/// F1.14 Phase 5 粘贴探针 UI 测试。
///
/// 从 `TagEntryUITests` 拆分以控制文件长度。覆盖：
/// - UI-ENTRY-003/005 paste positive control
/// - UI-ENTRY-001~006 标签点击负向断言
final class TagEntryPasteProbeUITests: XCTestCase
{
    // MARK: - 稳定夹具常量

    /// `previewClips[0]` 的稳定 UUID（code 类型，有标签夹具）。
    private let firstClipIDString = "00000000-0000-4000-8000-000000000001"
    /// `previewClips[1]` 的稳定 UUID（link 类型，空标签夹具）。
    private let secondClipIDString = "00000000-0000-4000-8000-000000000002"
    /// 第一个用户标签 ID（标准夹具 "工作"）。
    private let firstUserTagID = "user.00000000-0000-4000-8000-000000000101"

    /// 粘贴探针哨兵值：receiver 未收到粘贴事件时保持此值。
    private let pasteSentinel = "TAG_PASTE_SENTINEL"

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

    // MARK: - 粘贴探针正向控制（UI-ENTRY-003/005）

    /// UI-ENTRY-003/005 paste positive control：快捷粘贴面板双击文本条目触发真实粘贴。
    func testQuickPaste_PasteProbe_PositiveControl()
    {
        let app = launchWithProbe(
            args: [
                "--UITEST_PREVIEW_DATA",
                "--UITEST_QUICK_PASTE_PANEL",
                "--UITEST_TAG_FIXTURE",
                "--UITEST_TAG_PASTE_PROBE"
            ],
            searchFieldID: "quickPasteSearchField"
        )

        let firstRow = app.descendants(matching: .any)["quickPasteRow_0_selected"].firstMatch
        XCTAssertTrue(firstRow.waitForExistence(timeout: 5), "面板第一行应存在")
        firstRow.doubleClick()

        XCTAssertTrue(
            waitForProbeTextNotEqual(pasteSentinel, timeout: 10, app: app),
            "双击粘贴后 receiver 文本应改变（收到 Cmd+V）"
        )
        XCTAssertEqual(
            app.staticTexts["tagPasteProbeEventCount"].label,
            "1",
            "粘贴事件计数应为 1"
        )

        let resetButton = app.buttons["tagPasteProbeReset"]
        XCTAssertTrue(resetButton.exists, "重置按钮应存在")
        resetButton.click()

        XCTAssertTrue(
            waitForProbeText(pasteSentinel, timeout: 5, app: app),
            "reset 后 receiver 应恢复 sentinel"
        )
        XCTAssertEqual(
            app.staticTexts["tagPasteProbeEventCount"].label,
            "0",
            "reset 后计数应恢复 0"
        )
    }

    // MARK: - 标签点击负向断言（UI-ENTRY-001~006 补全）

    /// UI-ENTRY-004 负向：菜单栏弹窗点击标签 pill 后 picker 出现、panel 不关闭、
    /// receiver 保持 sentinel、count 保持 0。
    func testPopover_TagPill_Click_NoPasteTriggered()
    {
        let app = launchWithProbe(
            args: [
                "--UITEST_SHOW_MAIN_WINDOW",
                "--UITEST_POPOVER_WINDOW",
                "--UITEST_PREVIEW_DATA",
                "--UITEST_TAG_FIXTURE",
                "--UITEST_TAG_PASTE_PROBE"
            ],
            searchFieldID: "popoverSearchField"
        )

        let popoverWindow = app.windows.containing(
            .textField,
            identifier: "popoverSearchField"
        ).firstMatch
        let tagPill = popoverWindow.buttons[
            "clipTag_\(firstClipIDString)_\(firstUserTagID)"
        ]
        XCTAssertTrue(
            tagPill.waitForExistence(timeout: 10),
            "弹窗应显示有标签条目的 pill"
        )
        tagPill.click()

        XCTAssertTrue(
            app.staticTexts["tagPickerTitle"].waitForExistence(timeout: 5),
            "点击 pill 应打开标签选择菜单"
        )
        XCTAssertTrue(app.textFields["popoverSearchField"].exists, "弹窗不应关闭")
        assertNoPasteTriggered(app: app)
    }

    /// UI-ENTRY-004 负向：菜单栏弹窗点击「+」后 picker 出现、panel 不关闭。
    func testPopover_TagAdd_Click_NoPasteTriggered()
    {
        let app = launchWithProbe(
            args: [
                "--UITEST_SHOW_MAIN_WINDOW",
                "--UITEST_POPOVER_WINDOW",
                "--UITEST_PREVIEW_DATA",
                "--UITEST_TAG_EMPTY_CLIP",
                "--UITEST_TAG_PASTE_PROBE"
            ],
            searchFieldID: "popoverSearchField"
        )

        let popoverWindow = app.windows.containing(
            .textField,
            identifier: "popoverSearchField"
        ).firstMatch
        let tagAddButton = popoverWindow.buttons["tagAdd_\(secondClipIDString)"]
        XCTAssertTrue(
            tagAddButton.waitForExistence(timeout: 10),
            "弹窗应显示无标签条目的「+」按钮"
        )
        tagAddButton.click()

        XCTAssertTrue(
            app.staticTexts["tagPickerTitle"].waitForExistence(timeout: 5),
            "点击「+」应打开标签选择菜单"
        )
        XCTAssertTrue(app.textFields["popoverSearchField"].exists, "弹窗不应关闭")
        assertNoPasteTriggered(app: app)
    }

    /// UI-ENTRY-005 负向：快捷粘贴面板点击标签 pill 后 picker 出现、高亮 ID 不变。
    func testQuickPaste_TagPill_Click_NoPasteTriggered()
    {
        let app = launchWithProbe(
            args: [
                "--UITEST_PREVIEW_DATA",
                "--UITEST_QUICK_PASTE_PANEL",
                "--UITEST_TAG_FIXTURE",
                "--UITEST_TAG_PASTE_PROBE"
            ],
            searchFieldID: "quickPasteSearchField"
        )

        XCTAssertTrue(
            app.descendants(matching: .any)["quickPasteRow_0_selected"].firstMatch.exists,
            "第一行应被选中"
        )

        let tagPill = app.buttons[
            "clipTag_\(firstClipIDString)_\(firstUserTagID)"
        ]
        XCTAssertTrue(
            tagPill.waitForExistence(timeout: 10),
            "快捷粘贴面板应显示有标签条目的 pill"
        )
        tagPill.click()

        XCTAssertTrue(
            app.staticTexts["tagPickerTitle"].waitForExistence(timeout: 5),
            "点击 pill 应打开标签选择菜单"
        )
        XCTAssertTrue(app.textFields["quickPasteSearchField"].exists, "面板不应关闭")
        XCTAssertTrue(
            app.descendants(matching: .any)["quickPasteRow_0_selected"].firstMatch.exists,
            "标签点击不应改变高亮 ID"
        )
        assertNoPasteTriggered(app: app)
    }

    /// UI-ENTRY-005 负向：快捷粘贴面板点击「+」后 picker 出现、高亮 ID 不变。
    func testQuickPaste_TagAdd_Click_NoPasteTriggered()
    {
        let app = launchWithProbe(
            args: [
                "--UITEST_PREVIEW_DATA",
                "--UITEST_QUICK_PASTE_PANEL",
                "--UITEST_TAG_EMPTY_CLIP",
                "--UITEST_TAG_PASTE_PROBE"
            ],
            searchFieldID: "quickPasteSearchField"
        )

        XCTAssertTrue(
            app.descendants(matching: .any)["quickPasteRow_0_selected"].firstMatch.exists,
            "第一行应被选中"
        )

        let tagAddButton = app.buttons["tagAdd_\(secondClipIDString)"]
        XCTAssertTrue(
            tagAddButton.waitForExistence(timeout: 10),
            "快捷粘贴面板应显示无标签条目的「+」按钮"
        )
        tagAddButton.click()

        XCTAssertTrue(
            app.staticTexts["tagPickerTitle"].waitForExistence(timeout: 5),
            "点击「+」应打开标签选择菜单"
        )
        XCTAssertTrue(app.textFields["quickPasteSearchField"].exists, "面板不应关闭")
        XCTAssertTrue(
            app.descendants(matching: .any)["quickPasteRow_0_selected"].firstMatch.exists,
            "「+」点击不应改变高亮 ID"
        )
        assertNoPasteTriggered(app: app)
    }
}

// MARK: - 粘贴探针辅助

private extension TagEntryPasteProbeUITests
{
    /// 启动带探针的 app 并激活接收文本框，验证探针处于 armed 状态。
    @discardableResult
    func launchWithProbe(args: [String], searchFieldID: String) -> XCUIApplication
    {
        let app = XCUIApplication()
        app.launchArguments = args
        app.launch()
        app.activate()

        let searchField = app.textFields[searchFieldID]
        XCTAssertTrue(
            searchField.waitForExistence(timeout: 10),
            "面板应出现"
        )

        let probeField = app.textFields["tagPasteProbeTextField"]
        XCTAssertTrue(
            probeField.waitForExistence(timeout: 10),
            "粘贴探针应出现"
        )
        probeField.click()
        XCTAssertTrue(
            waitForProbeText(pasteSentinel, timeout: 5, app: app),
            "探针应处于 armed 状态"
        )
        return app
    }

    /// 断言标签点击不触发粘贴：receiver 保持 sentinel，count 保持 0。
    func assertNoPasteTriggered(app: XCUIApplication)
    {
        XCTAssertEqual(
            app.textFields["tagPasteProbeTextField"].value as? String,
            pasteSentinel,
            "标签点击不应触发粘贴，receiver 应保持 sentinel"
        )
        XCTAssertEqual(
            app.staticTexts["tagPasteProbeEventCount"].label,
            "0",
            "标签点击不应触发粘贴，count 应保持 0"
        )
    }

    /// 等待探针接收文本框值变为指定值。
    @discardableResult
    func waitForProbeText(
        _ expected: String,
        timeout: TimeInterval,
        app: XCUIApplication
    ) -> Bool
    {
        let field = app.textFields["tagPasteProbeTextField"]
        let predicate = NSPredicate { element, _ in
            (element as? XCUIElement)?.value as? String == expected
        }
        let expectation = XCTNSPredicateExpectation(
            predicate: predicate,
            object: field
        )
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    /// 等待探针接收文本框值变为不等于指定值。
    @discardableResult
    func waitForProbeTextNotEqual(
        _ unexpected: String,
        timeout: TimeInterval,
        app: XCUIApplication
    ) -> Bool
    {
        let field = app.textFields["tagPasteProbeTextField"]
        let predicate = NSPredicate { element, _ in
            ((element as? XCUIElement)?.value as? String) != unexpected
        }
        let expectation = XCTNSPredicateExpectation(
            predicate: predicate,
            object: field
        )
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}
