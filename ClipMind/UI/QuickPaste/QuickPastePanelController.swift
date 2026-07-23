import AppKit
import SwiftUI

/// 面板定位协议（依赖注入，便于测试 mock 不同定位策略）。
///
/// Phase 1 只有屏幕中央/上次位置策略；Phase 4 会新增 caret 定位策略。
protocol PanelScreenLocating: AnyObject
{
    /// 计算面板显示位置。
    /// - Parameter lastClosedPosition: 上次关闭时记录的位置（nil 表示无记忆）
    /// - Returns: 面板左下角坐标（NSPanel 使用左下角原点）
    func locatePosition(lastClosedPosition: NSPoint?) -> NSPoint
}

/// 快速粘贴面板控制器。
///
/// 管理 NSPanel 的创建、定位、显示、关闭、键盘焦点、失焦监听、位置记忆。
/// 状态机：Closed → Showing → Closed（Phase 1）；Phase 2/3 扩展 Pasting 状态。
///
/// 设计文档第 3.1 节、第 5.1 节。
final class QuickPastePanelController
{
    /// 面板固定尺寸（与菜单栏 popover 视觉一致）。
    static let panelSize = NSSize(width: 360, height: 480)

    /// 面板位置记忆的 UserDefaults 键。
    private static let lastClosedPositionXKey = "F1.9.quickPaste.lastClosedPositionX"
    private static let lastClosedPositionYKey = "F1.9.quickPaste.lastClosedPositionY"

    private let screenLocator: PanelScreenLocating
    private var panel: NSPanel?
    private var lastClosedPosition: NSPoint?

    /// 面板当前是否可见（状态机：Closed=false, Showing=true）。
    private(set) var isPanelVisible = false

    init(screenLocator: PanelScreenLocating)
    {
        self.screenLocator = screenLocator
        loadLastClosedPosition()
    }

    deinit
    {
        closePanelInternal()
    }

    // MARK: - 显示与关闭

    /// 显示面板（若已显示则忽略，保证状态机单一性）。
    func showPanel()
    {
        guard !isPanelVisible else
        {
            LogCategory.ui.info("QuickPaste panel already visible, ignore show request")
            return
        }

        let panel = makePanel()
        self.panel = panel

        let position = screenLocator.locatePosition(lastClosedPosition: lastClosedPosition)
        panel.setFrameOrigin(position)
        panel.makeKeyAndOrderFront(nil)
        isPanelVisible = true
        LogCategory.ui.info("QuickPaste panel shown at position")
    }

    /// 关闭面板（若已关闭则忽略，保证状态机单一性）。
    /// 关闭时记录面板位置（供下次无权限定位使用）。
    func closePanel()
    {
        closePanelInternal()
    }

    private func closePanelInternal()
    {
        guard isPanelVisible, let panel = panel else { return }

        let frame = panel.frame
        recordLastClosedPosition(NSPoint(x: frame.origin.x, y: frame.origin.y))

        panel.orderOut(nil)
        self.panel = nil
        isPanelVisible = false
        LogCategory.ui.info("QuickPaste panel closed, position recorded")
    }

    // MARK: - 测试辅助

    /// 仅供单元测试读取面板当前 frame（生产代码不使用）。
    var panelFrameForTesting: NSRect
    {
        panel?.frame ?? .zero
    }

    // MARK: - 私有

    private func makePanel() -> NSPanel
    {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: Self.panelSize),
            styleMask: [.titled, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        // F1.9 失焦关闭由 didResignKeyNotification 处理（任务 5 实现）
        return panel
    }

    private func loadLastClosedPosition()
    {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: Self.lastClosedPositionXKey) != nil,
              defaults.object(forKey: Self.lastClosedPositionYKey) != nil
        else { return }
        let positionX = defaults.double(forKey: Self.lastClosedPositionXKey)
        let positionY = defaults.double(forKey: Self.lastClosedPositionYKey)
        lastClosedPosition = NSPoint(x: positionX, y: positionY)
    }

    private func recordLastClosedPosition(_ position: NSPoint)
    {
        lastClosedPosition = position
        let defaults = UserDefaults.standard
        defaults.set(position.x, forKey: Self.lastClosedPositionXKey)
        defaults.set(position.y, forKey: Self.lastClosedPositionYKey)
    }
}
