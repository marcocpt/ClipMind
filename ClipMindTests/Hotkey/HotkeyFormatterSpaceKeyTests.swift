@testable import ClipMind
import XCTest

/// F1.10 AC-F1.10-1 / AC-F1.10-2：验证 HotkeyFormatter 对空格键的解析与显示支持。
final class HotkeyFormatterSpaceKeyTests: XCTestCase
{
    // MARK: - AC-F1.10-1：解析新默认值返回空格键码与命令、Shift 修饰键

    func testParse_NewDefault_ReturnsSpaceKeyCodeAndCmdShiftModifiers()
    {
        // Arrange
        let stored = TestHotkeys.default

        // Act
        let parsed = HotkeyFormatter.parse(stored: stored)

        // Assert
        XCTAssertNotNil(parsed, "新默认值应能被解析")
        XCTAssertEqual(parsed?.keyCode, 49, "空格键的 keyCode 应为 49")
        XCTAssertTrue((parsed?.modifiers ?? 0) & 0x0100 != 0, "修饰键应包含 cmdKey (0x0100)")
        XCTAssertTrue((parsed?.modifiers ?? 0) & 0x0200 != 0, "修饰键应包含 shiftKey (0x0200)")
    }
}
