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
///
/// Phase 5 新增 probe 模式分支：
/// 1. 有注入 `eventSender` 时走 mock（单元测试）；
/// 2. 普通 `--UITEST_QUICK_PASTE_PANEL` 继续跳过；
/// 3. probe 模式且 safety policy 为 true 时调用真实 `sendViaCGEvent()`；
/// 4. probe 模式但安全条件失败时跳过并发布仅含固定结果码的可访问性失败状态。
final class PasteSimulator
{
    /// V 键的 keyCode（macOS 固定值）。
    static let vKeyCode: Int64 = 9

    /// UI 测试启动参数下的 UserDefaults 标记键（用于 UI 测试验证 simulatePaste 被调用）。
    private static let uiTestCalledKey = "UITest_pasteSimulatorCalled"

    /// UI 测试启动参数（任务 7 的 test hook）。
    private static let uiTestLaunchArg = "--UITEST_QUICK_PASTE_PANEL"

    /// Phase 5：probe 模式失败标记键（供 XCUITest 读取安全失败状态）。
    private static let probeSafetyFailedKey = "UITest_tagPasteProbeSafetyFailed"

    private let eventSender: PasteEventSending?

    /// Phase 5：粘贴事件安全策略。默认策略始终返回 false；
    /// probe 模式下注入 `TagPasteProbeSafetyPolicy`。
    private let safetyPolicy: PasteEventSafetyChecking

    /// - Parameters:
    ///   - eventSender: 按键事件发送器（测试注入 mock；生产用 nil 表示使用真实 CGEvent 实现）
    ///   - safetyPolicy: 粘贴事件安全策略（默认 `DefaultPasteEventSafetyPolicy`）
    init(
        eventSender: PasteEventSending? = nil,
        safetyPolicy: PasteEventSafetyChecking = DefaultPasteEventSafetyPolicy()
    )
    {
        self.eventSender = eventSender
        self.safetyPolicy = safetyPolicy
    }

    /// 模拟系统标准 Cmd+V 粘贴按键。
    ///
    /// 发送顺序：Cmd 按下 + V 按下 → V 释放 + Cmd 释放。
    /// 仅发送标准粘贴按键，不发送其他按键序列（TC-F1.9-SEC-03）。
    ///
    /// 分支固定为：
    /// 1. 有注入 `eventSender` 时走 mock（单元测试）；
    /// 2. 普通 `--UITEST_QUICK_PASTE_PANEL` 继续跳过；
    /// 3. probe 模式且 safety policy 为 true 时调用真实 `sendViaCGEvent()`；
    /// 4. probe 模式但安全条件失败时跳过并发布仅含固定结果码的可访问性失败状态。
    func simulatePaste()
    {
        let isUITestMode = ProcessInfo.processInfo.arguments.contains(Self.uiTestLaunchArg)
        let isProbeMode = TagUITestSupport.shouldEnablePasteProbe

        // 分支 1：有注入 eventSender 时走 mock（单元测试）
        if let eventSender = eventSender
        {
            sendViaMock(eventSender)
            LogCategory.ui.info("Paste simulated: Cmd+V sent")
        }
        // 分支 3：probe 模式且安全条件满足时发送真实 CGEvent
        else if isProbeMode && safetyPolicy.isSafeToSendPasteEvent()
        {
            sendViaCGEvent()
            LogCategory.ui.info("Paste simulated: probe mode, Cmd+V sent")
        }
        // 分支 4：probe 模式但安全条件失败时跳过并标记
        else if isProbeMode
        {
            UserDefaults.standard.set(true, forKey: Self.probeSafetyFailedKey)
            LogCategory.ui.info("Paste skipped: probe mode safety check failed")
        }
        // 分支 2：普通 UI 测试模式跳过 CGEvent
        else if isUITestMode
        {
            LogCategory.ui.info("Paste simulated (UI test mode): CGEvent skipped")
        }
        // 生产路径：发送真实 CGEvent
        else
        {
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
