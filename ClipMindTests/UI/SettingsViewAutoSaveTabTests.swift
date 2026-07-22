import SwiftUI
import XCTest

@testable import ClipMind

final class SettingsViewAutoSaveTabTests: XCTestCase
{
    // MARK: - TC-UT-68：SettingsTab 枚举包含 autoSave case

    @MainActor
    func testSettingsTabHasAutoSaveCase() throws
    {
        // 实现前 SettingsTab.autoSave 不存在 → 编译失败（TDD red）
        let tab: SettingsTab = .autoSave
        XCTAssertEqual(tab, .autoSave, "SettingsTab 应包含 .autoSave case")
    }

    // MARK: - TC-UT-69：--UITEST_INITIAL_TAB=autosave 参数解析为 autoSave tab

    @MainActor
    func testAutoSaveTabArgumentParsing() throws
    {
        // 实现前 SettingsView.tabFromArgument 不存在 → 编译失败（TDD red）
        let tab = SettingsView.tabFromArgument("--UITEST_INITIAL_TAB=autosave")
        XCTAssertEqual(tab, .autoSave, "autosave 参数应解析为 .autoSave tab")
    }

    // MARK: - TC-UT-69b：未知参数回退到 apiKey tab（不破坏 F1.x 既有行为）

    @MainActor
    func testUnknownTabArgumentFallsBackToApiKey() throws
    {
        let tab = SettingsView.tabFromArgument("--UITEST_INITIAL_TAB=unknown")
        XCTAssertEqual(tab, .apiKey, "未知参数应回退到 .apiKey tab（F1.x 既有行为）")
    }
}
