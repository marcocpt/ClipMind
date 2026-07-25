import AppKit
import XCTest

/// 菜单栏弹窗底部工具栏 UI 测试（F1.11 Phase 3 任务 5 ~ 任务 7）。
///
/// 通过 `--UITEST_POPOVER_WINDOW` 启动参数在独立 NSWindow 中承载 UnifiedPastePanelView，
/// 使 XCUITest 能稳定定位底部工具栏三按钮（查看全部 / 配置 / 退出）。
///
/// 关联 AC：
/// - AC-F1.11-6：「查看全部」按钮关闭弹窗并打开主窗口
/// - AC-F1.11-7：「配置」按钮关闭弹窗并打开设置窗口
/// - AC-F1.11-8：「退出」按钮仅关闭弹窗，不打开其他窗口，不写入剪贴板
/// - AC-F1.11-13：菜单栏弹窗场景底部工具栏三按钮均可见
final class PopoverBottomToolbarUITests: XCTestCase
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

    // MARK: - AC-F1.11-13 三按钮可见性

    /// 验证菜单栏弹窗场景底部工具栏三按钮均存在。
    func test01_BottomToolbar_ThreeButtonsVisible()
    {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_POPOVER_WINDOW",
            "--UITEST_PREVIEW_DATA"
        ]
        app.launch()
        app.activate()

        let searchField = app.textFields["popoverSearchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5), "弹窗应出现")

        // 三按钮均应存在
        XCTAssertTrue(
            app.buttons["popoverViewAllButton"].waitForExistence(timeout: 3),
            "「查看全部」按钮应存在"
        )
        XCTAssertTrue(
            app.buttons["popoverSettingsButton"].exists,
            "「配置」按钮应存在"
        )
        XCTAssertTrue(
            app.buttons["popoverExitButton"].exists,
            "「退出」按钮应存在"
        )
    }

    // MARK: - AC-F1.11-6 「查看全部」按钮

    /// 验证「查看全部」按钮点击后：弹窗关闭 + 主窗口出现。
    func test02_ViewAllButton_ClosesPopoverAndOpensMainWindow()
    {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_POPOVER_WINDOW",
            "--UITEST_PREVIEW_DATA"
        ]
        app.launch()
        app.activate()

        let searchField = app.textFields["popoverSearchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5), "弹窗应出现")

        let viewAllButton = app.buttons["popoverViewAllButton"]
        XCTAssertTrue(viewAllButton.waitForExistence(timeout: 3), "「查看全部」按钮应出现")

        // 点击前重新激活应用，避免「Application is not foreground」竞态
        app.activate()
        viewAllButton.click()

        // 弹窗应关闭（搜索框不再存在）
        XCTAssertFalse(
            searchField.waitForExistence(timeout: 2),
            "「查看全部」应关闭弹窗"
        )

        // 主窗口应出现（通过主窗口工具栏的 settingsButton 验证）
        let settingsButton = app.buttons["settingsButton"]
        XCTAssertTrue(
            settingsButton.waitForExistence(timeout: 5),
            "主窗口应出现并可见"
        )
    }

    // MARK: - AC-F1.11-7 「配置」按钮

    /// 验证「配置」按钮点击后：弹窗关闭 + 设置窗口出现。
    func test03_SettingsButton_ClosesPopoverAndOpensSettingsWindow()
    {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_POPOVER_WINDOW",
            "--UITEST_PREVIEW_DATA"
        ]
        app.launch()
        app.activate()

        let searchField = app.textFields["popoverSearchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))

        let settingsButton = app.buttons["popoverSettingsButton"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 3))

        // 点击前重新激活应用，避免「Application is not foreground」竞态
        app.activate()
        settingsButton.click()

        // 弹窗应关闭
        XCTAssertFalse(
            searchField.waitForExistence(timeout: 2),
            "「配置」应关闭弹窗"
        )

        // 设置窗口应出现（标题为 "ClipMind Settings"）
        let settingsWindow = app.windows["ClipMind Settings"]
        XCTAssertTrue(
            settingsWindow.waitForExistence(timeout: 5),
            "设置窗口应出现"
        )
    }

    // MARK: - AC-F1.11-8 「退出」按钮

    /// 验证「退出」按钮点击后：弹窗关闭 + 不打开新窗口 + 剪贴板内容不变。
    ///
    /// F1.11 Bug Fix：生产环境下「退出」按钮调用 `NSApp.terminate(nil)` 退出整个应用；
    /// UITEST 模式下 `PopoverPreviewWindowFactory` 将 `onExitApp` 注入为 `window?.close()`，
    /// 模拟「退出」行为避免终止测试进程，使 XCUITest 能验证按钮被触发且无副作用。
    func test04_ExitButton_ClosesPopoverOnly()
    {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_POPOVER_WINDOW",
            "--UITEST_PREVIEW_DATA"
        ]
        app.launch()
        app.activate()

        // 预置剪贴板内容
        let pasteboard = NSPasteboard.general
        let originalContent = "ORIGINAL_CLIPBOARD_FOR_EXIT_TEST"
        pasteboard.clearContents()
        pasteboard.setString(originalContent, forType: .string)

        let searchField = app.textFields["popoverSearchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))

        let exitButton = app.buttons["popoverExitButton"]
        XCTAssertTrue(exitButton.waitForExistence(timeout: 3))

        // 点击前重新激活应用，避免「Application is not foreground」竞态
        app.activate()
        exitButton.click()

        // 弹窗应关闭
        XCTAssertFalse(
            searchField.waitForExistence(timeout: 2),
            "「退出」应关闭弹窗"
        )

        // 剪贴板内容不变
        let currentContent = pasteboard.string(forType: .string)
        XCTAssertEqual(
            currentContent,
            originalContent,
            "「退出」不应写入剪贴板"
        )
    }

    /// 验证「退出」按钮点击后不打开设置窗口。
    func test05_ExitButton_DoesNotOpenSettingsWindow()
    {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_POPOVER_WINDOW",
            "--UITEST_PREVIEW_DATA"
        ]
        app.launch()
        app.activate()

        let searchField = app.textFields["popoverSearchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))

        let exitButton = app.buttons["popoverExitButton"]
        XCTAssertTrue(exitButton.waitForExistence(timeout: 3))

        // 点击前重新激活应用，避免「Application is not foreground」竞态
        app.activate()
        exitButton.click()

        // 设置窗口不应出现
        let settingsWindow = app.windows["ClipMind Settings"]
        XCTAssertFalse(
            settingsWindow.waitForExistence(timeout: 2),
            "「退出」不应打开设置窗口"
        )
    }
}
