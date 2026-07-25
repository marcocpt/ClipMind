@testable import ClipMind
import Foundation
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
        let defaults = makeIsolatedDefaults()
        var settings = AppSettings()
        settings.hotkey = TestHotkeys.legacyDefault

        // Act
        let migrated = settings.migrateLegacyHotkey(userDefaults: defaults)

        // Assert
        XCTAssertTrue(migrated, "旧默认值应触发迁移")
        XCTAssertEqual(settings.hotkey, AppSettings.defaultHotkey, "旧默认值应被迁移为新默认值")
        XCTAssertEqual(settings.hotkey, TestHotkeys.default, "迁移后应等于测试常量集的当前默认值")
        XCTAssertEqual(
            defaults.string(forKey: "hotkey"),
            TestHotkeys.default,
            "迁移后应写回 UserDefaults"
        )
    }

    // MARK: - AC-F1.10-5：迁移幂等性（已迁移的值不再被修改）

    func testMigrateLegacyHotkey_WhenNewDefault_DoesNotMigrate()
    {
        // Arrange - 已迁移为新默认值
        let defaults = makeIsolatedDefaults()
        var settings = AppSettings()
        settings.hotkey = TestHotkeys.default

        // Act
        let migrated = settings.migrateLegacyHotkey(userDefaults: defaults)

        // Assert
        XCTAssertFalse(migrated, "已是新默认值时不应触发迁移")
        XCTAssertEqual(settings.hotkey, TestHotkeys.default, "已是新默认值时，迁移检查不应修改")
        XCTAssertNil(defaults.string(forKey: "hotkey"), "未触发迁移时不应写回 UserDefaults")
    }

    // MARK: - AC-F1.10-6：老用户自定义值保留不变

    func testMigrateLegacyHotkey_WhenCustomValue_KeepsCustomValue()
    {
        // Arrange - 用户自定义的快捷键（非旧默认值）
        let defaults = makeIsolatedDefaults()
        var settings = AppSettings()
        settings.hotkey = TestHotkeys.arbitrary

        // Act
        let migrated = settings.migrateLegacyHotkey(userDefaults: defaults)

        // Assert
        XCTAssertFalse(migrated, "自定义值不应触发迁移")
        XCTAssertEqual(settings.hotkey, TestHotkeys.arbitrary, "自定义值不应被覆盖")
        XCTAssertNil(defaults.string(forKey: "hotkey"), "未触发迁移时不应写回 UserDefaults")
    }

    // MARK: - AC-F1.10-6：空值或无效值不强制覆盖为新默认值

    func testMigrateLegacyHotkey_WhenEmptyValue_DoesNotMigrate()
    {
        // Arrange - 空字符串（用户主动清空）
        let defaults = makeIsolatedDefaults()
        var settings = AppSettings()
        settings.hotkey = ""

        // Act
        let migrated = settings.migrateLegacyHotkey(userDefaults: defaults)

        // Assert
        XCTAssertFalse(migrated, "空值不应触发迁移")
        XCTAssertEqual(settings.hotkey, "", "空值不应被覆盖为新默认值")
        XCTAssertNil(defaults.string(forKey: "hotkey"), "未触发迁移时不应写回 UserDefaults")
    }

    func testMigrateLegacyHotkey_WhenInvalidValue_DoesNotMigrate()
    {
        // Arrange - 无效值
        let defaults = makeIsolatedDefaults()
        var settings = AppSettings()
        settings.hotkey = "invalid"

        // Act
        let migrated = settings.migrateLegacyHotkey(userDefaults: defaults)

        // Assert
        XCTAssertFalse(migrated, "无效值不应触发迁移")
        XCTAssertEqual(settings.hotkey, "invalid", "无效值不应被覆盖为新默认值")
        XCTAssertNil(defaults.string(forKey: "hotkey"), "未触发迁移时不应写回 UserDefaults")
    }

    // MARK: - 端到端集成测试：从 UserDefaults 初始化 + 迁移

    /// 验证应用启动路径：老用户持久化旧默认值，init(userDefaults:) 读取后迁移应写回新值。
    func testAppSettings_InitFromUserDefaults_PerformsLegacyMigration()
    {
        // Arrange - 模拟老用户 UserDefaults 中的旧默认值
        let defaults = makeIsolatedDefaults()
        defaults.set(TestHotkeys.legacyDefault, forKey: "hotkey")

        // Act - 应用启动路径：从 UserDefaults 读取 + 迁移
        var settings = AppSettings(userDefaults: defaults)
        let migrated = settings.migrateLegacyHotkey(userDefaults: defaults)

        // Assert
        XCTAssertTrue(migrated, "应发生迁移")
        XCTAssertEqual(settings.hotkey, TestHotkeys.default, "迁移后内存中的 hotkey 应为新默认值")
        XCTAssertEqual(
            defaults.string(forKey: "hotkey"),
            TestHotkeys.default,
            "UserDefaults 应被写回新默认值"
        )
    }

    /// 验证应用启动路径：用户自定义值不应被迁移覆盖。
    func testAppSettings_InitFromUserDefaults_PreservesCustomValue()
    {
        // Arrange - 模拟用户自定义快捷键
        let defaults = makeIsolatedDefaults()
        defaults.set(TestHotkeys.arbitrary, forKey: "hotkey")

        // Act
        var settings = AppSettings(userDefaults: defaults)
        let migrated = settings.migrateLegacyHotkey(userDefaults: defaults)

        // Assert
        XCTAssertFalse(migrated, "自定义值不应触发迁移")
        XCTAssertEqual(settings.hotkey, TestHotkeys.arbitrary, "自定义值应保留")
        XCTAssertEqual(
            defaults.string(forKey: "hotkey"),
            TestHotkeys.arbitrary,
            "UserDefaults 应保留自定义值"
        )
    }

    /// 验证应用启动路径：无持久化值时使用新默认值，且不触发迁移。
    func testAppSettings_InitFromUserDefaults_UsesDefaultWhenNoPersistentValue()
    {
        // Arrange - 全新安装，UserDefaults 中无 hotkey 键
        let defaults = makeIsolatedDefaults()

        // Act
        var settings = AppSettings(userDefaults: defaults)
        let migrated = settings.migrateLegacyHotkey(userDefaults: defaults)

        // Assert
        XCTAssertFalse(migrated, "无持久化值不应触发迁移")
        XCTAssertEqual(settings.hotkey, TestHotkeys.default, "无持久化值应使用新默认值")
        XCTAssertNil(defaults.string(forKey: "hotkey"), "未触发迁移时不应写回 UserDefaults")
    }

    // MARK: - 辅助方法

    /// 创建隔离的 UserDefaults suite，并在测试结束后清理。
    /// 使用 #function 作为 suiteName，避免与其他测试交叉污染。
    private func makeIsolatedDefaults(file: StaticString = #file, line: UInt = #line) -> UserDefaults
    {
        let suiteName = "ClipMindTests.AppSettings.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("无法创建隔离的 UserDefaults suite", file: file, line: line)
            return .standard
        }
        addTeardownBlock {
            defaults.removePersistentDomain(forName: suiteName)
        }
        return defaults
    }
}
