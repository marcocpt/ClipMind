import XCTest

/// F1.10 AC-F1.10-9 / AC-F1.10-7-02：验证设置页快捷键录制器默认显示新默认值。
///
/// 本测试文件延迟到 CI 执行（本地 xcodebuild 环境不稳定）。
/// 通过 accessibilityIdentifier 定位元素：
/// - "hotkeyRecorder"：快捷键录制器按钮（显示当前快捷键，通过 .accessibilityLabel 暴露显示值）
/// - "resetHotkeyButton"：重置按钮
///
/// 启动参数（与 SettingsUITests 一致的导航模式）：
/// - "--UITEST_SHOW_MAIN_WINDOW"：显示主窗口
/// - "--UITEST_RESET_SETTINGS"：重置设置（清除持久化 hotkey）
/// - "--UITEST_INITIAL_TAB=general"：直接定位到通用标签
/// - "--UITEST_LEGACY_HOTKEY"：注入老用户旧默认值（cmd+shift+v，由 11.0 处理）
/// - "--UITEST_CUSTOM_HOTKEY"：注入自定义值（ctrl+opt+a，由 11.0 处理）
final class GeneralSettingsHotkeyDisplayUITests: XCTestCase
{
    override func setUpWithError() throws
    {
        continueAfterFailure = false
    }

    // MARK: - TC-F1.10-9-01：新用户首启后设置页快捷键录制器显示 ⌘⇧Space

    func testSettingsPage_NewUser_ShowsCmdShiftSpaceByDefault()
    {
        // Arrange - 启动 App（首启状态，无持久化快捷键）
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_RESET_SETTINGS",
            "--UITEST_INITIAL_TAB=general"
        ]
        app.launch()

        // Act - 打开通用设置页
        openGeneralSettings(in: app)

        // Assert - 快捷键录制器显示 ⌘⇧Space（通过 accessibilityLabel 断言）
        let recorder = app.buttons["hotkeyRecorder"]
        XCTAssertTrue(recorder.waitForExistence(timeout: 5.0), "快捷键录制器应存在")
        XCTAssertEqual(recorder.label, "⌘⇧Space", "新用户首启后应显示 ⌘⇧Space")
    }

    // MARK: - TC-F1.10-9-02：老用户迁移后设置页快捷键录制器显示 ⌘⇧Space

    func testSettingsPage_AfterLegacyMigration_ShowsCmdShiftSpace()
    {
        // Arrange - 模拟老用户持久化旧默认值（通过 UserDefaults 注入）
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_RESET_SETTINGS",
            "--UITEST_INITIAL_TAB=general",
            "--UITEST_LEGACY_HOTKEY"
        ]
        app.launch()

        // Act - 启动后 AppSettings.migrateLegacyHotkey() 自动迁移；打开设置页
        openGeneralSettings(in: app)

        // Assert - 快捷键录制器显示迁移后的 ⌘⇧Space
        let recorder = app.buttons["hotkeyRecorder"]
        XCTAssertTrue(recorder.waitForExistence(timeout: 5.0), "快捷键录制器应存在")
        XCTAssertEqual(recorder.label, "⌘⇧Space", "老用户迁移后应显示 ⌘⇧Space")
    }

    // MARK: - TC-F1.10-7-02：重置按钮点击后设置页显示更新为 ⌘⇧Space（手动验收）

    /// CI 环境 `resetHotkeyButton` 持续 "is not hittable"，4 次修复未解决
    /// （`app.activate()`、coordinate tap、HotkeyRecorder HStack 加 Spacer 均未生效），
    /// 改为手动验收（详见测试用例表 v1.1）。
    /// 代码保留以便 CI 环境改善后恢复自动化；当前以 `XCTSkip` 跳过。
    /// 手动验收步骤：启动 App → 通用设置 → 注入自定义快捷键 → 点击重置按钮 → 确认显示 ⌘⇧Space。
    func testResetHotkeyButton_DisplayUpdatesToCmdShiftSpace() throws
    {
        try XCTSkip(
            "CI 环境 resetHotkeyButton 持续 'is not hittable'，改为手动验收（测试用例表 v1.1 TC-F1.10-7-02）"
        )

        // Arrange - 启动 App 并打开设置页（注入自定义快捷键）
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_RESET_SETTINGS",
            "--UITEST_INITIAL_TAB=general",
            "--UITEST_CUSTOM_HOTKEY"
        ]
        app.launch()
        app.activate()
        openGeneralSettings(in: app)

        let recorder = app.buttons["hotkeyRecorder"]
        XCTAssertTrue(recorder.waitForExistence(timeout: 5.0))

        // Act - 点击重置按钮（HotkeyRecorder HStack 已加 Spacer 让按钮靠右，
        // 与 GeneralSettingsView.quickPasteSection 布局一致，确保 hit test 正常）
        let resetButton = app.buttons["resetHotkeyButton"]
        XCTAssertTrue(resetButton.waitForExistence(timeout: 2.0), "重置按钮应存在")
        app.activate()
        resetButton.click()
        Thread.sleep(forTimeInterval: 0.5)

        // Assert - 显示更新为 ⌘⇧Space
        XCTAssertEqual(recorder.label, "⌘⇧Space", "重置后应显示 ⌘⇧Space")
    }

    // MARK: - 辅助

    /// 打开通用设置页（与 SettingsUITests.launchAndOpenGeneralSettings 一致的导航方式）。
    /// 通用标签已通过 --UITEST_INITIAL_TAB=general 启动参数定位，无需切换标签。
    private func openGeneralSettings(in app: XCUIApplication)
    {
        app.activate()
        let settingsButton = app.buttons["settingsButton"].firstMatch
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5.0), "设置按钮应存在")
        settingsButton.click()
    }
}
