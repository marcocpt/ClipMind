@testable import ClipMind
import XCTest

/// F1.10 AC-F1.10-7：验证 AppSettings.defaultHotkey 常量与 TestHotkeys.default 一致。
///
/// 注：本测试仅验证常量一致性，真实重置行为由 TC-F1.10-7-02 XCUITest 验证
/// （`GeneralSettingsHotkeyDisplayUITests.testResetHotkeyButton_DisplayUpdatesToCmdShiftSpace`）。
final class HotkeyRecorderResetTests: XCTestCase
{
    func testAppSettingsDefaultHotkeyConstant_IsConsistentWithTestHotkeys()
    {
        // Arrange & Act & Assert - 验证生产代码常量与测试常量集保持一致
        XCTAssertEqual(
            AppSettings.defaultHotkey,
            TestHotkeys.default,
            "AppSettings.defaultHotkey 应与 TestHotkeys.default 保持一致"
        )
    }

    func testResetHotkeyButton_NewDefaultIsDisplayable()
    {
        // Arrange - 重置后的值必须能被 HotkeyFormatter 正确显示
        let resetValue = AppSettings.defaultHotkey

        // Act
        let displayed = HotkeyFormatter.display(resetValue)

        // Assert
        XCTAssertEqual(displayed, "⌘⇧Space", "重置后的新默认值应能被显示为 ⌘⇧Space")
    }
}
