import AppKit
@testable import ClipMind
import XCTest

/// F1.10 AC-F1.10-3 / AC-F1.10-10：验证 HotkeyFormatter 反向构造与往返互逆。
final class HotkeyFormatterRoundTripTests: XCTestCase
{
    // MARK: - AC-F1.10-3：反向构造新默认值

    func testParse_ModifiersAndSpaceKeyCode_ReturnsNewDefaultStorageRepresentation()
    {
        // Arrange - cmdKey (0x0100) + shiftKey (0x0200) + 空格 keyCode (49)
        let modifiers: NSEvent.ModifierFlags = [.command, .shift]
        let keyCode: UInt16 = 49

        // Act
        let stored = HotkeyFormatter.parse(modifiers: modifiers, keyCode: keyCode)

        // Assert
        XCTAssertEqual(stored, TestHotkeys.default, "反向构造结果应等于新默认值的存储表示")
    }

    // MARK: - AC-F1.10-3：解析与反向构造互逆（往返测试）

    func testRoundTrip_NewDefault_PreservesStorageRepresentation()
    {
        // Arrange
        let original = TestHotkeys.default

        // Act - 解析 → 反向构造
        let parsed = HotkeyFormatter.parse(stored: original)
        XCTAssertNotNil(parsed)
        let roundTrip = HotkeyFormatter.parse(
            modifiers: carbonModifiersToNSEventModifiers(parsed!.modifiers),
            keyCode: UInt16(parsed!.keyCode)
        )

        // Assert
        XCTAssertEqual(roundTrip, original, "新默认值解析后反向构造应与原输入一致")
    }

    // MARK: - AC-F1.10-10：旧默认值回归保护（解析仍正确 + 往返互逆）

    func testRoundTrip_LegacyDefault_PreservesStorageRepresentation()
    {
        // Arrange
        let original = TestHotkeys.legacyDefault

        // Act - 解析 → 反向构造
        let parsed = HotkeyFormatter.parse(stored: original)
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.keyCode, 9, "旧默认值的 keyCode 应为 9 (v)")
        let roundTrip = HotkeyFormatter.parse(
            modifiers: carbonModifiersToNSEventModifiers(parsed!.modifiers),
            keyCode: UInt16(parsed!.keyCode)
        )

        // Assert
        XCTAssertEqual(roundTrip, original, "旧默认值解析后反向构造应与原输入一致（回归保护）")
    }

    // MARK: - 辅助

    /// 把 Carbon 修饰键 mask 转回 NSEvent.ModifierFlags，用于往返测试。
    private func carbonModifiersToNSEventModifiers(_ carbon: UInt32) -> NSEvent.ModifierFlags
    {
        var flags: NSEvent.ModifierFlags = []
        if carbon & 0x0100 != 0 { flags.insert(.command) }
        if carbon & 0x0200 != 0 { flags.insert(.shift) }
        if carbon & 0x0800 != 0 { flags.insert(.option) }
        if carbon & 0x1000 != 0 { flags.insert(.control) }
        return flags
    }
}
