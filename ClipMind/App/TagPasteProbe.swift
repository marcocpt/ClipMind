#if CLIPMIND_DEV
import AppKit
import Foundation

/// Phase 5：粘贴探针接收窗口。
///
/// 仅在 `CLIPMIND_DEV + --UITEST_TAG_PASTE_PROBE` 下创建。提供一个真实可编辑
/// `NSTextField`，初始值为 `TAG_PASTE_SENTINEL`。当真实 Cmd+V 事件到达时，
/// `controlTextDidChange` 增加 `pasteEventCount`。
///
/// 探针不写磁盘，不发送日志，不在 Release 编译。
///
/// XCUITest 通过以下 accessibility identifier 读取状态：
/// - `tagPasteProbeTextField`：接收文本框
/// - `tagPasteProbeReset`：重置按钮
/// - `tagPasteProbeEventCount`：事件计数（只读标签）
final class TagPasteProbe: NSObject, NSTextFieldDelegate
{
    /// 哨兵初始值：接收文本框未收到粘贴事件时保持此值。
    static let sentinel = "TAG_PASTE_SENTINEL"

    /// 接收窗口。
    private let panel: NSPanel

    /// 接收文本框。
    let textField: NSTextField

    /// 重置按钮（XCUITest 通过 `tagPasteProbeReset` 读取）。
    let resetButton: NSButton

    /// 事件计数标签（XCUITest 通过 `tagPasteProbeEventCount` 读取）。
    let countLabel: NSTextField

    /// 粘贴事件计数：真实文本变化时 +1。
    private(set) var pasteEventCount = 0

    /// 接收文本框当前文本。
    var pasteReceiverText: String
    {
        textField.stringValue
    }

    /// 接收文本框是否聚焦（probe window 为 key window 且 textField 是 first responder）。
    var pasteReceiverFocused: Bool
    {
        panel.isKeyWindow && panel.firstResponder === textField
    }

    /// 接收文本框与计数是否处于已 reset 状态。
    var isArmed: Bool
    {
        textField.stringValue == Self.sentinel && pasteEventCount == 0
    }

    override init()
    {
        self.panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 120),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        panel.title = "TagPasteProbe"
        panel.isFloatingPanel = true
        panel.level = .floating

        self.textField = NSTextField(frame: NSRect(x: 20, y: 60, width: 280, height: 24))
        textField.stringValue = TagPasteProbe.sentinel
        textField.identifier = NSUserInterfaceItemIdentifier("tagPasteProbeTextField")
        textField.isBordered = true
        textField.isEditable = true
        textField.placeholderString = "等待粘贴事件"

        self.countLabel = NSTextField(labelWithString: "0")
        countLabel.identifier = NSUserInterfaceItemIdentifier("tagPasteProbeEventCount")
        countLabel.isEditable = false
        countLabel.isBordered = false
        countLabel.frame = NSRect(x: 20, y: 30, width: 100, height: 20)

        self.resetButton = NSButton(
            frame: NSRect(x: 200, y: 30, width: 100, height: 24)
        )
        resetButton.title = "Reset"
        resetButton.bezelStyle = .rounded
        resetButton.identifier = NSUserInterfaceItemIdentifier("tagPasteProbeReset")

        super.init()

        textField.delegate = self
        resetButton.target = self
        resetButton.action = #selector(reset)

        let contentView = panel.contentView ?? NSView()
        contentView.addSubview(textField)
        contentView.addSubview(countLabel)
        contentView.addSubview(resetButton)
    }

    /// 显示窗口并使接收文本框成为 first responder。
    func show()
    {
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(textField)
    }

    /// 关闭窗口。
    func close()
    {
        panel.close()
    }

    /// 重置探针：恢复 sentinel、计数归零、重新聚焦。
    @objc func reset()
    {
        textField.stringValue = Self.sentinel
        pasteEventCount = 0
        countLabel.stringValue = "0"
        if panel.isKeyWindow
        {
            panel.makeFirstResponder(textField)
        }
    }

    // MARK: - NSTextFieldDelegate

    /// 真实文本变化时增加计数并更新标签。
    func controlTextDidChange(_ notification: Notification)
    {
        pasteEventCount += 1
        countLabel.stringValue = "\(pasteEventCount)"
    }

    /// 判断探针窗口是否为 key window。
    var isKeyWindow: Bool
    {
        panel.isKeyWindow
    }
}

// MARK: - PasteEventSafetyChecking

/// Phase 5：粘贴事件安全检查协议。
///
/// 默认策略在任何 UI-test 参数下返回 false；只有 `TagPasteProbeSafetyPolicy`
/// 在 probe 模式且安全条件全满足时才返回 true。
protocol PasteEventSafetyChecking: AnyObject
{
    /// 是否允许发送真实 CGEvent 粘贴按键。
    func isSafeToSendPasteEvent() -> Bool
}

/// 默认安全策略：任何 UI-test 参数下都返回 false。
final class DefaultPasteEventSafetyPolicy: PasteEventSafetyChecking
{
    func isSafeToSendPasteEvent() -> Bool
    {
        false
    }
}

/// Probe 模式安全策略：只有同时满足以下条件才返回 true：
/// - 存在 `--UITEST_TAG_PASTE_PROBE`
/// - probe window 仍是 key window
/// - receiver 仍是 first responder
/// - receiver sentinel 和 eventCount 都处于已 reset 状态
final class TagPasteProbeSafetyPolicy: PasteEventSafetyChecking
{
    private let probe: TagPasteProbe

    init(probe: TagPasteProbe)
    {
        self.probe = probe
    }

    func isSafeToSendPasteEvent() -> Bool
    {
        guard TagUITestSupport.shouldEnablePasteProbe else
        {
            return false
        }
        guard probe.isKeyWindow else
        {
            return false
        }
        guard probe.pasteReceiverFocused else
        {
            return false
        }
        guard probe.isArmed else
        {
            return false
        }
        return true
    }
}
#endif
