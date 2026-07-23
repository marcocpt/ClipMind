import CoreGraphics
import Foundation

#if CLIPMIND_DEV

/// 粘贴按键事件发送协议（依赖注入，便于测试 mock）。
///
/// 设计文档第 3.6 节。仅发送系统标准粘贴按键（Cmd+V），不发送任意按键序列。
protocol PasteEventSending: AnyObject
{
    /// 发送按键事件。
    /// - Parameters:
    ///   - keyCode: 按键码（V 键 = 9）
    ///   - keyDown: true = 按下，false = 释放
    ///   - withCommand: 是否使用 Command 修饰键
    ///   - withOtherModifiers: 是否使用其他修饰键（Option/Control/Shift）
    func sendKeyEvent(
        keyCode: Int64,
        keyDown: Bool,
        withCommand: Bool,
        withOtherModifiers: Bool
    )
}

/// 粘贴模拟协议（依赖注入，便于测试 mock）。
///
/// 设计文档第 3.6 节。PasteSimulator 默认实现遵循此协议。
protocol PasteSimulating: AnyObject
{
    /// 模拟系统标准粘贴按键。
    func simulatePaste()
}

/// 使 PasteSimulator 遵循 PasteSimulating 协议。
extension PasteSimulator: PasteSimulating {}

/// 模拟粘贴按键模块（合规待定，仅 ClipMind-Dev Scheme 编译）。
///
/// 设计文档第 3.6 节 + 第 10.3 节「合规待定」标注。
/// 职责：接收粘贴流程协调器的委托，模拟系统标准粘贴按键到前台应用。
///
/// 合规说明：
/// - 仅发送系统标准 Cmd+V 按键（keyCode 9 + Command 修饰键）
/// - 不发送任意按键序列（NFR-003 安全性）
/// - 响应用户双击操作触发单次粘贴（非批量自动化）
/// - 使用公开 CGEvent API（CoreGraphics）
final class PasteSimulator
{
    /// V 键的 keyCode（macOS 固定值）。
    static let vKeyCode: Int64 = 9

    /// UI 测试启动参数下的 UserDefaults 标记键（用于 UI 测试验证 simulatePaste 被调用）。
    private static let uiTestCalledKey = "UITest_pasteSimulatorCalled"

    /// UI 测试启动参数（任务 7 的 test hook）。
    private static let uiTestLaunchArg = "--UITEST_QUICK_PASTE_PANEL"

    private let eventSender: PasteEventSending?

    /// - Parameter eventSender: 按键事件发送器（测试注入 mock；生产用 nil 表示使用真实 CGEvent 实现）
    init(eventSender: PasteEventSending? = nil)
    {
        self.eventSender = eventSender
    }

    /// 模拟系统标准 Cmd+V 粘贴按键。
    ///
    /// 发送顺序：Cmd 按下 + V 按下 → V 释放 + Cmd 释放。
    /// 仅发送标准粘贴按键，不发送其他按键序列（TC-F1.9-SEC-03）。
    ///
    /// UI 测试模式（`--UITEST_QUICK_PASTE_PANEL` 启动参数）下跳过 CGEvent 发送：
    /// 面板关闭后前台应用不可预测（可能是 WPS Office/Finder 等），
    /// 真实 Cmd+V 会激活该应用并干扰 XCUITest 元素查询。
    /// 仅记录调用标记供 UI 测试验证。
    func simulatePaste()
    {
        let isUITestMode = ProcessInfo.processInfo.arguments.contains(Self.uiTestLaunchArg)

        if let eventSender = eventSender
        {
            sendViaMock(eventSender)
            LogCategory.ui.info("Paste simulated: Cmd+V sent")
        } else if isUITestMode {
            LogCategory.ui.info("Paste simulated (UI test mode): CGEvent skipped")
        } else {
            sendViaCGEvent()
            LogCategory.ui.info("Paste simulated: Cmd+V sent")
        }

        // test hook：UI 测试启动参数下记录 simulatePaste() 被调用，供 UI 测试验证
        if isUITestMode
        {
            UserDefaults.standard.set(true, forKey: Self.uiTestCalledKey)
        }
    }

    // MARK: - 私有

    private func sendViaMock(_ eventSender: PasteEventSending)
    {
        eventSender.sendKeyEvent(
            keyCode: Self.vKeyCode,
            keyDown: true,
            withCommand: true,
            withOtherModifiers: false
        )
        eventSender.sendKeyEvent(
            keyCode: Self.vKeyCode,
            keyDown: false,
            withCommand: true,
            withOtherModifiers: false
        )
    }

    private func sendViaCGEvent()
    {
        let source = CGEventSource(stateID: .hidSystemState)

        let keyDown = CGEvent(
            keyboardEventSource: source,
            virtualKey: CGKeyCode(Self.vKeyCode),
            keyDown: true
        )
        keyDown?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)

        let keyUp = CGEvent(
            keyboardEventSource: source,
            virtualKey: CGKeyCode(Self.vKeyCode),
            keyDown: false
        )
        keyUp?.flags = .maskCommand
        keyUp?.post(tap: .cghidEventTap)
    }
}

#endif
