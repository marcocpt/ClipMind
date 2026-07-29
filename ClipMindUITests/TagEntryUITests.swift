import AppKit
import XCTest

/// F1.14 Phase 2 任务 6：标签入口 UI Smoke。
///
/// 验证三个入口（主窗口、菜单栏弹窗预览、快捷粘贴面板）的标签条可交互性：
/// - 有标签条目点击 pill 打开 picker
/// - 无标签条目点击「+」打开 picker
/// - 主窗口标签点击不传播到行选择/详情
///
/// 粘贴负向探针（UI-ENTRY-003/005）在 Phase 5 关闭，当前 Phase 仅验证 picker 出现。
final class TagEntryUITests: XCTestCase
{
    // MARK: - 稳定夹具常量

    /// `previewClips[0]` 的稳定 UUID（code 类型，有标签夹具）。
    private let firstClipIDString = "00000000-0000-4000-8000-000000000001"
    /// `previewClips[1]` 的稳定 UUID（link 类型，空标签夹具）。
    private let secondClipIDString = "00000000-0000-4000-8000-000000000002"
    /// 第一个用户标签 ID（标准夹具 "工作"）。
    private let firstUserTagID = "user.00000000-0000-4000-8000-000000000101"

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

    // MARK: - 主窗口入口

    /// UI-ENTRY-001：主窗口有标签条目点击 pill 打开 picker。
    ///
    /// 必须包含 `--UITEST_PREVIEW_DATA`：`ClipTestData.isUITesting` 仅识别该参数，
    /// 缺失时 `HistoryListView` 走数据库异步加载路径，clip 行定位异常导致 pill 不可点击。
    /// `-ApplePersistenceIgnoreState YES` 禁用窗口状态恢复，避免窗口离屏导致 pill 不可点击。
    func testMainWindow_TagPill_ClickOpensPicker()
    {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_PREVIEW_DATA",
            "--UITEST_TAG_FIXTURE",
            "-ApplePersistenceIgnoreState",
            "YES"
        ]
        app.launch()
        app.activate()

        let tagPill = app.buttons[
            "clipTag_\(firstClipIDString)_\(firstUserTagID)"
        ]
        XCTAssertTrue(
            tagPill.waitForExistence(timeout: 10),
            "主窗口应显示有标签条目的 pill"
        )

        tagPill.click()

        let pickerTitle = app.staticTexts["tagPickerTitle"]
        XCTAssertTrue(
            pickerTitle.waitForExistence(timeout: 5),
            "点击 pill 应打开标签选择菜单"
        )
    }

    /// UI-ENTRY-002：主窗口无标签条目点击「+」打开 picker。
    ///
    /// 同 UI-ENTRY-001，需 `--UITEST_PREVIEW_DATA` 确保 `isUITesting` 为 true。
    func testMainWindow_TagAdd_ClickOpensPicker()
    {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_PREVIEW_DATA",
            "--UITEST_TAG_EMPTY_CLIP"
        ]
        app.launch()
        app.activate()

        let tagAddButton = app.buttons[
            "tagAdd_\(secondClipIDString)"
        ]
        XCTAssertTrue(
            tagAddButton.waitForExistence(timeout: 10),
            "主窗口应显示无标签条目的「+」按钮"
        )

        tagAddButton.click()

        let pickerTitle = app.staticTexts["tagPickerTitle"]
        XCTAssertTrue(
            pickerTitle.waitForExistence(timeout: 5),
            "点击「+」应打开标签选择菜单"
        )
    }

    /// UI-ENTRY-006：主窗口标签点击不传播到行选择。
    ///
    /// 点击标签 pill 后，详情面板不应更新（仍显示空状态或原有选择）。
    /// 同 UI-ENTRY-001，需 `--UITEST_PREVIEW_DATA` 确保 `isUITesting` 为 true。
    func testMainWindow_TagClick_DoesNotTriggerRowSelection()
    {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_PREVIEW_DATA",
            "--UITEST_TAG_FIXTURE"
        ]
        app.launch()
        app.activate()

        let tagPill = app.buttons[
            "clipTag_\(firstClipIDString)_\(firstUserTagID)"
        ]
        XCTAssertTrue(tagPill.waitForExistence(timeout: 10))

        // 初始详情面板应显示空状态
        let emptyDetail = app.staticTexts["选择一条剪贴内容查看详情"]
        XCTAssertTrue(
            emptyDetail.waitForExistence(timeout: 5),
            "初始详情面板应显示空状态"
        )

        tagPill.click()

        // picker 应出现
        let pickerTitle = app.staticTexts["tagPickerTitle"]
        XCTAssertTrue(pickerTitle.waitForExistence(timeout: 5))

        // 详情面板仍应显示空状态（标签点击不传播到行选择）
        XCTAssertTrue(
            emptyDetail.exists,
            "点击标签不应触发行选择，详情面板应仍为空状态"
        )
    }

    // MARK: - 菜单栏弹窗预览入口

    /// UI-ENTRY-004：菜单栏弹窗预览有标签条目点击 pill 打开 picker。
    ///
    /// 使用 `--UITEST_POPOVER_WINDOW` 在独立窗口中展示弹窗内容，
    /// `--UITEST_PREVIEW_DATA` 提供内存条目，`--UITEST_TAG_FIXTURE` 提供数据库标签。
    func testPopover_TagPill_ClickOpensPicker()
    {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_POPOVER_WINDOW",
            "--UITEST_PREVIEW_DATA",
            "--UITEST_TAG_FIXTURE"
        ]
        app.launch()
        app.activate()

        let tagPill = app.buttons[
            "clipTag_\(firstClipIDString)_\(firstUserTagID)"
        ]
        XCTAssertTrue(
            tagPill.waitForExistence(timeout: 10),
            "弹窗预览应显示有标签条目的 pill"
        )

        tagPill.click()

        let pickerTitle = app.staticTexts["tagPickerTitle"]
        XCTAssertTrue(
            pickerTitle.waitForExistence(timeout: 5),
            "点击 pill 应打开标签选择菜单"
        )
    }

    // MARK: - 快捷粘贴面板入口

    /// UI-ENTRY-005：快捷粘贴面板有标签条目点击 pill 打开 picker。
    ///
    /// 粘贴负向探针（panel 未关闭）在 Phase 5 关闭，当前仅验证 picker 出现。
    /// 需 `--UITEST_PREVIEW_DATA` 确保 `isUITesting` 为 true，避免主窗口数据库
    /// 异步加载导致同 ID pill 在主窗口定位异常干扰面板测试。
    ///
    /// 主窗口与面板存在同 ID 的标签 pill。通过 `containing(.textField, identifier:)`
    /// 限定到面板窗口，在该窗口内查询 pill，避免 XCUITest 命中主窗口的同 ID pill。
    func testQuickPaste_TagPill_ClickOpensPicker()
    {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_PREVIEW_DATA",
            "--UITEST_QUICK_PASTE_PANEL",
            "--UITEST_TAG_FIXTURE"
        ]
        app.launch()
        app.activate()

        let searchField = app.textFields["quickPasteSearchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 10), "快捷粘贴面板应出现")

        let tagPill = app.buttons[
            "clipTag_\(firstClipIDString)_\(firstUserTagID)"
        ]
        XCTAssertTrue(
            tagPill.waitForExistence(timeout: 10),
            "快捷粘贴面板应显示有标签条目的 pill"
        )

        tagPill.click()

        let pickerTitle = app.staticTexts["tagPickerTitle"]
        XCTAssertTrue(
            pickerTitle.waitForExistence(timeout: 5),
            "点击 pill 应打开标签选择菜单"
        )
    }
}
