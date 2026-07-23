import Foundation
import XCTest

@testable import ClipMind

#if CLIPMIND_DEV

/// 模拟粘贴按键模块测试（Phase 4，仅 ClipMind-Dev Scheme 编译）。
///
/// 覆盖 TC-F1.9-SEC-03：模拟粘贴仅发送系统标准 Cmd+V 按键。
final class PasteSimulatorTests: XCTestCase
{
    // MARK: - TC-F1.9-SEC-03 模拟粘贴仅发送系统标准粘贴按键

    func testSimulatePaste_SendsOnlyStandardPasteKeystroke()
    {
        let mock = MockPasteEventSender()
        let simulator = PasteSimulator(eventSender: mock)

        simulator.simulatePaste()

        XCTAssertEqual(mock.sentKeyCodes.count, 2, "应发送 2 个按键事件（按下 + 释放）")
        XCTAssertTrue(mock.sentKeyCodes.contains(PasteSimulator.vKeyCode), "应包含 V 键 keyCode")
        XCTAssertTrue(mock.commandModifierUsed, "应使用 Command 修饰键")
        XCTAssertFalse(mock.otherModifiersUsed, "不应使用其他修饰键（如 Option/Control）")
    }

    // MARK: - 模拟粘贴发送标准 Cmd+V（不发送其他按键序列）

    func testSimulatePaste_DoesNotSendArbitraryKeySequence()
    {
        let mock = MockPasteEventSender()
        let simulator = PasteSimulator(eventSender: mock)

        simulator.simulatePaste()

        // 仅允许 V 键，不允许其他字母/数字键
        for keyCode in mock.sentKeyCodes
        {
            XCTAssertEqual(
                keyCode,
                PasteSimulator.vKeyCode,
                "仅允许 V 键，实际发送 keyCode: \(keyCode)"
            )
        }
    }

    // MARK: - 默认实现使用真实 CGEvent（验证不崩溃）

    func testSimulatePaste_RealEventSender_DoesNotCrash()
    {
        let simulator = PasteSimulator()
        XCTAssertNoThrow(simulator.simulatePaste(), "模拟粘贴按键不应抛出异常")
    }

    // MARK: - 测试辅助 Mock

    private final class MockPasteEventSender: PasteEventSending
    {
        var sentKeyCodes: [Int64] = []
        var commandModifierUsed = false
        var otherModifiersUsed = false

        func sendKeyEvent(
            keyCode: Int64,
            keyDown: Bool,
            withCommand: Bool,
            withOtherModifiers: Bool
        )
        {
            sentKeyCodes.append(keyCode)
            if withCommand
            {
                commandModifierUsed = true
            }
            if withOtherModifiers
            {
                otherModifiersUsed = true
            }
        }
    }
}

#endif
