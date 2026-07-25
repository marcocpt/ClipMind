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

    // MARK: - AC-F1.10-5：老用户旧默认值自动迁移为新默认值

    func testMigrateLegacyHotkey_WhenLegacyDefault_MigratesToNewDefault()
    {
        // Arrange - 老用户持久化的快捷键为旧默认值
        var settings = AppSettings()
        settings.hotkey = TestHotkeys.legacyDefault

        // Act
        settings.migrateLegacyHotkey()

        // Assert
        XCTAssertEqual(settings.hotkey, AppSettings.defaultHotkey, "旧默认值应被迁移为新默认值")
        XCTAssertEqual(settings.hotkey, TestHotkeys.default, "迁移后应等于测试常量集的当前默认值")
    }

    // MARK: - AC-F1.10-5：迁移幂等性（已迁移的值不再被修改）

    func testMigrateLegacyHotkey_WhenNewDefault_DoesNotMigrate()
    {
        // Arrange - 已迁移为新默认值
        var settings = AppSettings()
        settings.hotkey = TestHotkeys.default

        // Act
        settings.migrateLegacyHotkey()

        // Assert
        XCTAssertEqual(settings.hotkey, TestHotkeys.default, "已是新默认值时，迁移检查不应修改")
    }

    // MARK: - AC-F1.10-6：老用户自定义值保留不变

    func testMigrateLegacyHotkey_WhenCustomValue_KeepsCustomValue()
    {
        // Arrange - 用户自定义的快捷键（非旧默认值）
        var settings = AppSettings()
        settings.hotkey = TestHotkeys.arbitrary

        // Act
        settings.migrateLegacyHotkey()

        // Assert
        XCTAssertEqual(settings.hotkey, TestHotkeys.arbitrary, "自定义值不应被覆盖")
    }

    // MARK: - AC-F1.10-6：空值或无效值不强制覆盖为新默认值

    func testMigrateLegacyHotkey_WhenEmptyValue_DoesNotMigrate()
    {
        // Arrange - 空字符串（用户主动清空）
        var settings = AppSettings()
        settings.hotkey = ""

        // Act
        settings.migrateLegacyHotkey()

        // Assert
        XCTAssertEqual(settings.hotkey, "", "空值不应被覆盖为新默认值")
    }

    func testMigrateLegacyHotkey_WhenInvalidValue_DoesNotMigrate()
    {
        // Arrange - 无效值
        var settings = AppSettings()
        settings.hotkey = "invalid"

        // Act
        settings.migrateLegacyHotkey()

        // Assert
        XCTAssertEqual(settings.hotkey, "invalid", "无效值不应被覆盖为新默认值")
    }
}
