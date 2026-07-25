@testable import ClipMind
import XCTest

/// F1.10 AC-F1.10-8：验证新默认值 cmd+shift+space 可被全局快捷键服务注册并触发"打开快速粘贴面板"通知。
///
/// 复用 GlobalHotkeyServiceTests 中的 MockHotkeyRegistrar（同 target 可见）。
final class GlobalHotkeyServiceNewDefaultTests: XCTestCase
{
    // MARK: - TC-F1.10-8-01：新默认值可被全局快捷键服务注册成功

    func testGlobalHotkeyService_InitWithNewDefault_RegistersWithSpaceKeyCode()
    {
        // Arrange
        let mock = MockHotkeyRegistrar()

        // Act - 使用新默认值初始化服务
        let service = GlobalHotkeyService(hotkey: TestHotkeys.default, registrar: mock)

        // Assert
        XCTAssertTrue(service.isRegistered, "新默认值应注册成功")
        XCTAssertEqual(mock.registeredKeyCode, 49, "应注册空格键码 49")
        XCTAssertNotNil(mock.registeredModifiers)
        XCTAssertTrue(mock.registeredModifiers! & 0x0100 != 0, "修饰键应包含 cmdKey")
        XCTAssertTrue(mock.registeredModifiers! & 0x0200 != 0, "修饰键应包含 shiftKey")

        _ = service
    }

    // MARK: - TC-F1.10-8-02：按下新默认值触发"打开快速粘贴面板"通知

    func testGlobalHotkeyService_NewDefaultPressed_PostsOpenQuickPasteNotification()
    {
        // Arrange
        let mock = MockHotkeyRegistrar()
        let service = GlobalHotkeyService(hotkey: TestHotkeys.default, registrar: mock)

        // Act - 监听通知并模拟快捷键按下
        let expectation = XCTNSNotificationExpectation(name: .openQuickPaste)
        mock.simulateHotkeyPressed()

        // Assert
        wait(for: [expectation], timeout: 1.0)

        _ = service
    }
}
