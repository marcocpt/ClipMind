import AppKit
import XCTest

/// 菜单栏弹窗图片 / 文件路径双击提示 UI 测试（F1.11 Phase 2 任务 6）。
///
/// 从 `PopoverDoublePasteUITests` 拆分出来，避免单文件超过 SwiftLint `file_length` 500 行限制。
/// 通过 `--UITEST_POPOVER_WINDOW` 启动参数在独立 NSWindow 中承载 UnifiedPastePanelView，
/// 使用 `--UITEST_PREPOPULATE_IMAGE_AND_FILEPATH` 注入图片 / 文件路径 / 文本三类数据。
final class PopoverHintUITests: XCTestCase
{
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

    /// 清理 EncryptedStore 数据库，避免上次测试残留数据干扰预置数据顺序。
    /// 沿用 F1.9 `QuickPasteOverlayUITests.cleanUpDatabase` 的实现方式。
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

    // MARK: - AC-F1.11-9 图片 / 文件路径双击提示

    /// 验证双击图片类型行显示「仅支持文本粘贴」提示。
    /// 预置顺序（timestamp 降序）：image（row 0）→ filePath（row 1）→ text（row 2）。
    func test06_DoubleClickImageRow_ShowsTextOnlyHint()
    {
        cleanUpDatabase()
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_POPOVER_WINDOW",
            "--UITEST_PREPOPULATE_IMAGE_AND_FILEPATH"
        ]
        app.launch()
        app.activate()

        let searchField = app.textFields["popoverSearchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))

        // image 在 row 0（默认高亮，identifier 带 _selected 后缀）
        let imageRow = app.descendants(matching: .any)["popoverRow_0_selected"].firstMatch
        XCTAssertTrue(imageRow.waitForExistence(timeout: 3), "图片行应存在")
        imageRow.doubleClick()

        // 应显示提示
        let hint = app.staticTexts["textOnlyHint"].firstMatch
        XCTAssertTrue(hint.waitForExistence(timeout: 3), "图片类型双击应显示提示")

        // 弹窗不应关闭（搜索框仍存在）
        XCTAssertTrue(searchField.exists, "图片类型双击不关闭弹窗")
    }

    /// 验证双击文件路径类型行显示「仅支持文本粘贴」提示。
    func test07_DoubleClickFilePathRow_ShowsTextOnlyHint()
    {
        cleanUpDatabase()
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_POPOVER_WINDOW",
            "--UITEST_PREPOPULATE_IMAGE_AND_FILEPATH"
        ]
        app.launch()
        app.activate()

        let searchField = app.textFields["popoverSearchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        // 先激活应用再 click，避免主窗口抢占焦点导致 click 失败
        app.activate()
        searchField.click()

        // filePath 在 row 1（非默认高亮，identifier 不带 _selected 后缀）
        let filePathRow = app.descendants(matching: .any)["popoverRow_1"].firstMatch
        XCTAssertTrue(filePathRow.waitForExistence(timeout: 3), "文件路径行应存在")
        app.activate()
        filePathRow.doubleClick()

        let hint = app.staticTexts["textOnlyHint"].firstMatch
        XCTAssertTrue(hint.waitForExistence(timeout: 3), "文件路径类型双击应显示提示")
    }

    /// 验证提示后单击其他行可清除提示。
    func test08_HintDismissedAfterClickingOtherRow()
    {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_POPOVER_WINDOW",
            "--UITEST_PREPOPULATE_IMAGE_AND_FILEPATH"
        ]
        app.launch()
        app.activate()

        let searchField = app.textFields["popoverSearchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        app.activate()
        searchField.click()

        // 双击 image 行（row 0）显示提示
        let imageRow = app.descendants(matching: .any)["popoverRow_0_selected"].firstMatch
        XCTAssertTrue(imageRow.waitForExistence(timeout: 3))
        app.activate()
        imageRow.doubleClick()

        let hint = app.staticTexts["textOnlyHint"].firstMatch
        XCTAssertTrue(hint.waitForExistence(timeout: 3), "应显示提示")

        // 单击 text 行（row 2）应清除提示
        let textRow = app.descendants(matching: .any)["popoverRow_2"].firstMatch
        XCTAssertTrue(textRow.waitForExistence(timeout: 3), "文本行应存在")
        app.activate()
        textRow.click()

        // 等待提示消失
        let hintCleared = NSPredicate(format: "exists == NO")
        let expectation = XCTNSPredicateExpectation(predicate: hintCleared, object: hint)
        wait(for: [expectation], timeout: 3.0)
        XCTAssertFalse(hint.exists, "点击其他行后提示应清除")
    }
}
