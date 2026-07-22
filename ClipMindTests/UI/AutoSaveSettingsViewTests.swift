import SwiftUI
import XCTest

@testable import ClipMind

final class AutoSaveSettingsViewTests: XCTestCase
{
    // MARK: - TC-UT-66：AutoSaveSettingsView 可实例化

    @MainActor
    func testAutoSaveSettingsViewInitializes() throws
    {
        let defaults = UserDefaults(suiteName: "test-ui-\(UUID().uuidString)")!
        let store = AutoSaveSettingsStore(defaults: defaults)
        let view = AutoSaveSettingsView(store: store)
        XCTAssertNotNil(view, "AutoSaveSettingsView 应能正常实例化")

        // 清理
        for key in defaults.dictionaryRepresentation().keys
        {
            defaults.removeObject(forKey: key)
        }
    }

    // MARK: - TC-UT-67：默认配置总开关关闭（D11）

    @MainActor
    func testDefaultSettingsIsEnabledFalse() throws
    {
        let defaults = UserDefaults(suiteName: "test-ui-\(UUID().uuidString)")!
        let store = AutoSaveSettingsStore(defaults: defaults)
        let settings = store.load()

        XCTAssertEqual(settings.isEnabled, false, "D11：总开关默认关闭")

        for key in defaults.dictionaryRepresentation().keys
        {
            defaults.removeObject(forKey: key)
        }
    }
}
