import AppKit

/// 面板键盘事件处理器（F1.11 Bug Fix：ESC 静默关闭）。
///
/// 消费特定键事件（返回 nil）以阻止传播到 NSResponder 链：
/// - ESC：避免触发 NSResponder.cancelOperation 默认实现调用 NSBeep()
///
/// 其他键原样返回，保留 TextField 编辑能力（方向键移动光标、Enter 不阻断）。
///
/// 设计权衡：仅消费 ESC 是因为 NSBeep 仅由 ESC 触发（NSResponder 默认 cancelOperation
/// 调用 NSBeep）；其他键传播不会产生提示音，且 TextField 需要这些键正常工作。
struct PanelKeyEventHandler
{
    let onEnter: () -> Void
    let onEsc: () -> Void
    let onMoveDown: () -> Void
    let onMoveUp: () -> Void

    /// 处理键盘事件。
    /// - Parameter event: 本地监听器捕获的 keyDown 事件
    /// - Returns: nil 表示消费事件（阻止传播），非 nil 表示继续传播原事件
    func handle(_ event: NSEvent) -> NSEvent?
    {
        switch event.keyCode
        {
        case 36: // Enter
            onEnter()
            return event
        case 53: // Esc
            onEsc()
            return nil
        case 125: // Down arrow
            onMoveDown()
            return event
        case 126: // Up arrow
            onMoveUp()
            return event
        default:
            return event
        }
    }
}
