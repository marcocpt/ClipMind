@testable import ClipMind
import XCTest

/// PanelKeyEventHandler 单元测试（F1.11 Bug Fix：ESC 静默关闭）。
///
/// 验证键盘事件路由契约：
/// - ESC 事件被消费（返回 nil），阻止传播到 NSResponder.cancelOperation 触发 NSBeep
/// - Enter / 方向键原样返回，保留 TextField 文本编辑能力
/// - 未处理键原样返回
@MainActor
final class PanelKeyEventHandlerTests: XCTestCase
{
    // MARK: - ESC 键（核心修复点）

    func test_handle_escKey_returnsNilToConsumeEvent() throws
    {
        var escCalled = false
        let handler = PanelKeyEventHandler(
            onEnter: {},
            onEsc: { escCalled = true },
            onMoveDown: {},
            onMoveUp: {}
        )
        let escEvent = try XCTUnwrap(makeKeyEvent(keyCode: 53))

        let result = handler.handle(escEvent)

        XCTAssertTrue(escCalled, "ESC 应触发 onEsc 回调")
        XCTAssertNil(result, "ESC 事件应被消费（返回 nil）以阻止 NSResponder.cancelOperation 触发 NSBeep")
    }

    // MARK: - Enter 键（保留原行为）

    func test_handle_enterKey_propagatesEvent() throws
    {
        var enterCalled = false
        let handler = PanelKeyEventHandler(
            onEnter: { enterCalled = true },
            onEsc: {},
            onMoveDown: {},
            onMoveUp: {}
        )
        let enterEvent = try XCTUnwrap(makeKeyEvent(keyCode: 36))

        let result = handler.handle(enterEvent)

        XCTAssertTrue(enterCalled, "Enter 应触发 onEnter 回调")
        XCTAssertEqual(result, enterEvent, "Enter 事件应原样返回，保留 TextField 编辑能力")
    }

    // MARK: - 方向键（保留原行为）

    func test_handle_downArrow_propagatesEvent() throws
    {
        var moveDownCalled = false
        let handler = PanelKeyEventHandler(
            onEnter: {},
            onEsc: {},
            onMoveDown: { moveDownCalled = true },
            onMoveUp: {}
        )
        let downEvent = try XCTUnwrap(makeKeyEvent(keyCode: 125))

        let result = handler.handle(downEvent)

        XCTAssertTrue(moveDownCalled, "Down 应触发 onMoveDown 回调")
        XCTAssertEqual(result, downEvent, "Down 事件应原样返回，保留 TextField 光标移动能力")
    }

    func test_handle_upArrow_propagatesEvent() throws
    {
        var moveUpCalled = false
        let handler = PanelKeyEventHandler(
            onEnter: {},
            onEsc: {},
            onMoveDown: {},
            onMoveUp: { moveUpCalled = true }
        )
        let upEvent = try XCTUnwrap(makeKeyEvent(keyCode: 126))

        let result = handler.handle(upEvent)

        XCTAssertTrue(moveUpCalled, "Up 应触发 onMoveUp 回调")
        XCTAssertEqual(result, upEvent, "Up 事件应原样返回，保留 TextField 光标移动能力")
    }

    // MARK: - 未处理键

    func test_handle_unhandledKey_propagatesEvent() throws
    {
        let handler = PanelKeyEventHandler(
            onEnter: {},
            onEsc: {},
            onMoveDown: {},
            onMoveUp: {}
        )
        // 'A' 键 keyCode = 0
        let aEvent = try XCTUnwrap(makeKeyEvent(keyCode: 0))

        let result = handler.handle(aEvent)

        XCTAssertEqual(result, aEvent, "未处理键应原样返回，不影响 TextField 正常输入")
    }

    // MARK: - 辅助

    /// 构造指定 keyCode 的 keyDown 事件（仅用于测试，无需真实图形上下文）。
    private func makeKeyEvent(keyCode: UInt16) -> NSEvent?
    {
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "",
            charactersIgnoringModifiers: "",
            isARepeat: false,
            keyCode: keyCode
        )
    }
}
