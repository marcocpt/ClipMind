@testable import ClipMind
import XCTest

/// 快捷键注册器 mock，用于测试 GlobalHotkeyService 的注册逻辑。
final class MockHotkeyRegistrar: HotkeyRegistering {
    var registeredKeyCode: UInt32?
    var registeredModifiers: UInt32?
    var isRegistered = false
    var shouldSucceed = true
    private var onTriggered: (() -> Void)?

    func register(keyCode: UInt32, modifiers: UInt32, onTriggered: @escaping () -> Void) -> Bool {
        self.registeredKeyCode = keyCode
        self.registeredModifiers = modifiers
        self.onTriggered = onTriggered
        isRegistered = shouldSucceed
        return shouldSucceed
    }

    func unregister() {
        isRegistered = false
        onTriggered = nil
    }

    /// 模拟快捷键被按下。
    func simulateHotkeyPressed() {
        onTriggered?()
    }
}

final class GlobalHotkeyServiceTests: XCTestCase {

    // MARK: - HotkeyFormatter.parse(stored:)

    func testParseStoredHotkey_CmdShiftV_ReturnsCorrectModifierAndKeyCode() {
        let parsed = HotkeyFormatter.parse(stored: "cmd+shift+v")
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.keyCode, 9) // keyCode for 'v'
        XCTAssertTrue(parsed?.modifiers ?? 0 != 0)
        // cmdKey=0x0100, shiftKey=0x0200 → 组合应包含这两位
        XCTAssertTrue((parsed?.modifiers ?? 0) & 0x0100 != 0) // cmdKey
        XCTAssertTrue((parsed?.modifiers ?? 0) & 0x0200 != 0) // shiftKey
    }

    func testParseStoredHotkey_CtrlOptA_ReturnsCorrectModifierAndKeyCode() {
        let parsed = HotkeyFormatter.parse(stored: "ctrl+opt+a")
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.keyCode, 0) // keyCode for 'a'
        XCTAssertTrue((parsed?.modifiers ?? 0) & 0x1000 != 0) // controlKey
        XCTAssertTrue((parsed?.modifiers ?? 0) & 0x0800 != 0) // optionKey
    }

    func testParseStoredHotkey_CmdOnly_ReturnsCorrectModifierAndKeyCode() {
        let parsed = HotkeyFormatter.parse(stored: "cmd+a")
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.keyCode, 0)
        XCTAssertTrue((parsed?.modifiers ?? 0) & 0x0100 != 0) // cmdKey
        // 不应包含其他修饰键
        XCTAssertEqual((parsed?.modifiers ?? 0) & ~UInt32(0x0100), 0)
    }

    func testParseStoredHotkey_InvalidFormat_ReturnsNil() {
        XCTAssertNil(HotkeyFormatter.parse(stored: "invalid"))
    }

    func testParseStoredHotkey_EmptyString_ReturnsNil() {
        XCTAssertNil(HotkeyFormatter.parse(stored: ""))
    }

    func testParseStoredHotkey_NoModifier_ReturnsNil() {
        // 只有字母没有修饰键 → 无效
        XCTAssertNil(HotkeyFormatter.parse(stored: "v"))
    }

    func testParseStoredHotkey_UnknownKey_ReturnsNil() {
        // 已知修饰键但未知字母
        XCTAssertNil(HotkeyFormatter.parse(stored: "cmd+zzz"))
    }

    // MARK: - GlobalHotkeyService（使用 Mock 注册器）

    func testGlobalHotkeyService_InitWithValidHotkey_RegistersWithCorrectParams() {
        let mock = MockHotkeyRegistrar()
        let service = GlobalHotkeyService(hotkey: "cmd+shift+v", registrar: mock)
        XCTAssertTrue(service.isRegistered, "有效的快捷键配置应成功注册")
        XCTAssertEqual(mock.registeredKeyCode, 9, "应注册 keyCode 9 (v)")
        XCTAssertNotNil(mock.registeredModifiers, "应注册修饰键")
        XCTAssertTrue(mock.registeredModifiers! & 0x0100 != 0, "修饰键应包含 cmdKey")
        XCTAssertTrue(mock.registeredModifiers! & 0x0200 != 0, "修饰键应包含 shiftKey")
    }

    func testGlobalHotkeyService_InitWithInvalidHotkey_IsNotRegistered() {
        let mock = MockHotkeyRegistrar()
        let service = GlobalHotkeyService(hotkey: "invalid", registrar: mock)
        XCTAssertFalse(service.isRegistered, "无效的快捷键配置不应注册")
        XCTAssertNil(mock.registeredKeyCode, "无效配置不应调用注册器")
    }

    func testGlobalHotkeyService_Unregister_ClearsRegistration() {
        let mock = MockHotkeyRegistrar()
        let service = GlobalHotkeyService(hotkey: "cmd+shift+v", registrar: mock)
        XCTAssertTrue(service.isRegistered)
        service.unregister()
        XCTAssertFalse(service.isRegistered, "注销后应不再处于注册状态")
        XCTAssertFalse(mock.isRegistered, "注册器也应注销")
    }

    func testGlobalHotkeyService_EmptyHotkey_IsNotRegistered() {
        let mock = MockHotkeyRegistrar()
        let service = GlobalHotkeyService(hotkey: "", registrar: mock)
        XCTAssertFalse(service.isRegistered, "空快捷键配置不应注册")
    }

    func testGlobalHotkeyService_RegistrarFails_IsNotRegistered() {
        let mock = MockHotkeyRegistrar()
        mock.shouldSucceed = false
        let service = GlobalHotkeyService(hotkey: "cmd+shift+v", registrar: mock)
        XCTAssertFalse(service.isRegistered, "注册器失败时不应标记为已注册")
    }

    // MARK: - 快捷键触发

    func testGlobalHotkeyService_HotkeyPressed_PostsOpenQuickPasteNotification() {
        let mock = MockHotkeyRegistrar()
        let service = GlobalHotkeyService(hotkey: "cmd+shift+v", registrar: mock)

        let expectation = XCTNSNotificationExpectation(name: .openQuickPaste)
        mock.simulateHotkeyPressed()
        wait(for: [expectation], timeout: 1.0)
        // 保持 service 引用避免被释放
        _ = service
    }
}
