import XCTest

@testable import ClipMind

final class AppDelegateAutoSaveAssemblyTests: XCTestCase
{
    // MARK: - TC-UT-70：resetAutoSaveSettings 清除全部 F2.1 配置键

    @MainActor
    func testResetAutoSaveSettingsClearsAllKeys() throws
    {
        let suite = "test-autosave-reset-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        // 预置全部 8 个 F2.1 配置键
        let keys = AppDelegate.autoSaveSettingsKeys
        for key in keys
        {
            defaults.set("test-value", forKey: key)
        }

        // 实现前 AppDelegate.resetAutoSaveSettings(in:) 不存在 → 编译失败（TDD red）
        AppDelegate.resetAutoSaveSettings(in: defaults)

        for key in keys
        {
            XCTAssertNil(defaults.object(forKey: key), "键 \(key) 应被清除")
        }
    }

    // MARK: - TC-UT-71：autoSaveSettingsKeys 包含全部 8 个配置项

    @MainActor
    func testAutoSaveSettingsKeysContainsAllEight() throws
    {
        // 实现前 AppDelegate.autoSaveSettingsKeys 不存在 → 编译失败（TDD red）
        let keys = AppDelegate.autoSaveSettingsKeys
        XCTAssertEqual(keys.count, 8, "应有 8 个 F2.1 配置键")
        XCTAssertTrue(keys.contains("F2.1.autoSave.isEnabled"), "应包含总开关键")
        XCTAssertTrue(keys.contains("F2.1.autoSave.saveDirectory"), "应包含保存目录键")
        XCTAssertTrue(keys.contains("F2.1.autoSave.whitelistBundleIds"), "应包含白名单键")
        XCTAssertTrue(keys.contains("F2.1.autoSave.fileFormat"), "应包含文件格式键")
        XCTAssertTrue(keys.contains("F2.1.autoSave.lengthThreshold"), "应包含长度阈值键")
        XCTAssertTrue(keys.contains("F2.1.autoSave.fileNameLength"), "应包含文件名长度键")
        XCTAssertTrue(keys.contains("F2.1.autoSave.sensitiveFilterEnabled"), "应包含敏感过滤键")
        XCTAssertTrue(keys.contains("F2.1.autoSave.pathFormat"), "应包含路径格式键")
    }
}
