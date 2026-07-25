@testable import ClipMind
import XCTest

/// F1.10 AC-F1.10-4 / AC-F1.10-5 / AC-F1.10-6：验证 AppSettings 默认值与老用户迁移。
final class AppSettingsHotkeyMigrationTests: XCTestCase
{
    // MARK: - AC-F1.10-4：应用设置默认快捷键为新默认值

    func testAppSettings_DefaultHotkey_IsNewDefault()
    {
        // Arrange & Act
        let settings = AppSettings()

        // Assert
        XCTAssertEqual(settings.hotkey, AppSettings.defaultHotkey, "默认快捷键应为 AppSettings.defaultHotkey")
        XCTAssertEqual(settings.hotkey, TestHotkeys.default, "默认快捷键应等于测试常量集的当前默认值")
    }
}
