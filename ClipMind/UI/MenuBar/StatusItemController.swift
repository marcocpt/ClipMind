import AppKit
import SwiftUI

extension Notification.Name
{
    static let openMainWindow = Notification.Name("ClipMindOpenMainWindow")
}

/// 状态栏图标控制器（F1.11 Phase 1）。
///
/// 管理菜单栏图标与菜单栏弹窗（NSPopover）。F1.11 新增：
/// - 实现 PanelClosing 协议，使 PasteCoordinator 通过统一接口关闭弹窗
/// - @MainActor 隔离，确保 UI 状态更新在主线程完成
/// - setup(encryptedStore:pasteCoordinator:) 入口，注入数据源与粘贴协调器
///
/// 设计文档第 3.1 节、第 6.2 节、第 6.3 节。
@MainActor
final class StatusItemController: NSObject, PanelClosing
{
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?

    /// 面板当前是否可见（PanelClosing 协议要求）。
    private(set) var isPanelVisible = false

    /// 注入的剪贴板存储（弹出弹窗前读取剪贴项列表）。
    private var encryptedStore: EncryptedStore?

    /// 注入的粘贴协调器（双击 / 回车触发粘贴流程）。
    private var pasteCoordinator: PasteCoordinator?

    /// 注入数据源与粘贴协调器（由 AppDelegate 在 configureActivationPolicy 中调用）。
    /// - Parameters:
    ///   - encryptedStore: 剪贴板加密存储
    ///   - pasteCoordinator: 粘贴流程协调器
    func setup(encryptedStore: EncryptedStore, pasteCoordinator: PasteCoordinator)
    {
        self.encryptedStore = encryptedStore
        self.pasteCoordinator = pasteCoordinator

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button
        {
            button.image = NSImage(
                systemSymbolName: "doc.on.clipboard.fill",
                accessibilityDescription: "ClipMind"
            )
            button.setAccessibilityLabel("ClipMind")
            button.target = self
            button.action = #selector(togglePopover)
        }
        popover = NSPopover()
        popover?.behavior = .transient
    }

    @objc private func togglePopover()
    {
        guard let popover = popover, let button = statusItem?.button else { return }
        if popover.isShown
        {
            popover.performClose(nil)
            isPanelVisible = false
        } else
        {
            popover.contentViewController = NSHostingController(
                rootView: makeUnifiedPanelView()
            )
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            isPanelVisible = true
        }
    }

    // MARK: - PanelClosing

    func closePanel()
    {
        guard isPanelVisible, let popover = popover else { return }
        popover.performClose(nil)
        isPanelVisible = false
        LogCategory.ui.info("Menu bar popover closed by PanelClosing protocol")
    }

    // MARK: - 私有

    /// 构造统一粘贴面板视图（菜单栏弹窗场景：显示底部工具栏）。
    private func makeUnifiedPanelView() -> UnifiedPastePanelView
    {
        let clips = loadClips()
        let viewModel = UnifiedPastePanelViewModel(clips: clips)
        viewModel.onPasteTriggered = { [weak self] clip in
            self?.pasteCoordinator?.handlePaste(clip: clip)
        }
        viewModel.onEscPressed = { [weak self] in
            self?.closePanel()
        }
        return UnifiedPastePanelView(
            viewModel: viewModel,
            showsBottomBar: true,
            accessibilityPrefix: "popover"
        )
    }

    /// 从剪贴板存储读取剪贴项列表（最多 50 条，与 F1.9 快捷键面板一致）。
    private func loadClips() -> [ClipItem]
    {
        guard let store = encryptedStore else { return [] }
        do
        {
            return Array(try store.loadAll().prefix(50))
        } catch
        {
            LogCategory.storage.error("加载菜单栏弹窗数据失败: \(error.localizedDescription)")
            return []
        }
    }
}
