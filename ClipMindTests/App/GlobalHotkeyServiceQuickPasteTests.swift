@testable import ClipMind
import XCTest

/// F1.9 Phase 1：验证全局快捷键触发行为从"唤起主窗口"改为"呼出快速粘贴面板"。
final class GlobalHotkeyServiceQuickPasteTests: XCTestCase
{
    // MARK: - TC-F1.9-1-02 快捷键触发发送"打开快速粘贴面板"通知

    func testHotkeyPressed_PostsOpenQuickPasteNotification()
    {
        let mock = MockHotkeyRegistrar()
        let service = GlobalHotkeyService(hotkey: "cmd+shift+v", registrar: mock)

        let quickPasteExpectation = XCTNSNotificationExpectation(name: .openQuickPaste)
        mock.simulateHotkeyPressed()
        wait(for: [quickPasteExpectation], timeout: 1.0)
        _ = service
    }

    // MARK: - 补充：快捷键触发不再发送"打开主窗口"通知

    func testHotkeyPressed_DoesNotPostOpenMainWindowNotification()
    {
        let mock = MockHotkeyRegistrar()
        let service = GlobalHotkeyService(hotkey: "cmd+shift+v", registrar: mock)

        let mainWindowExpectation = XCTNSNotificationExpectation(name: .openMainWindow)
        mainWindowExpectation.isInverted = true
        mock.simulateHotkeyPressed()
        wait(for: [mainWindowExpectation], timeout: 1.0)
        _ = service
    }
}
