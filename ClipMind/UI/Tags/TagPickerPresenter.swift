import AppKit
import SwiftUI

/// F1.14：标签选择器呈现器（单例）。
///
/// 用 `NSPanel` + `NSHostingController` 承载 `TagPickerView`，统一所有入口
/// （主窗口、菜单栏弹窗预览、快捷粘贴面板）的标签选择菜单呈现行为。
///
/// 背景问题：
/// 1. SwiftUI 的 `.popover()` 修饰符在手动创建的 `NSHostingController` +
///    `NSWindow` 中无法可靠工作（macOS 13 已知问题：hosting controller 缺少
///    view controller presentation context，导致 Button action 不触发、
///    popover 静默不显示）。
/// 2. `NSPopover` 虽然能 `show`，但内容窗口对 XCUITest 不可见：XCUITest 无法
///    查询到 NSPopover 内的 accessibility 元素（tagPickerTitle 等），导致 UI
///    测试超时。改用独立 `NSPanel` 后，picker 作为常规窗口出现在 accessibility
///    树中，XCUITest 可正常查询。
///
/// 用法：`TagStripContainer` 通过 `TagPickerAnchor` 取得锚点 `NSView`，在
/// `onActivate` 中调用 `TagPickerPresenter.shared.show(...)`。
@MainActor
final class TagPickerPresenter
{
    static let shared = TagPickerPresenter()

    /// 当前展示的 NSPanel。nil 表示未展示。
    private(set) var panel: NSPanel?

    /// 当前是否正在展示标签选择器。
    /// 供 `QuickPastePanelController.handleDidResignKey` 判断是否因 picker
    /// 抢占 key 而触发的失焦，避免快速粘贴面板被误关闭。
    var isShowing: Bool
    {
        panel?.isVisible ?? false
    }

    private init() {}

    /// 展示标签选择器。
    /// - Parameters:
    ///   - clipID: 目标剪贴条目 ID。
    ///   - contentType: 条目内容类型（用于系统标签过滤）。
    ///   - store: 共享标签状态。
    ///   - anchorView: 锚点视图。为 nil 时回退到当前 keyWindow 的 contentView。
    func show(
        clipID: UUID,
        contentType: ContentType,
        store: TagStore,
        relativeTo anchorView: NSView?
    )
    {
        close()

        let picker = TagPickerView(
            clipID: clipID,
            contentType: contentType,
            store: store
        )
        let hosting = NSHostingController(rootView: picker)

        // 锚点解析：优先用传入的 anchorView；为 nil 或无 window 时回退到 keyWindow.contentView。
        let resolvedAnchor: NSView?
        if let anchor = anchorView, anchor.window != nil
        {
            resolvedAnchor = anchor
        } else
        {
            resolvedAnchor = NSApp.keyWindow?.contentView
        }
        guard let anchor = resolvedAnchor
        else
        {
            NSLog("[DIAG] TagPickerPresenter.show: no anchor available, abort")
            return
        }

        // 锚点 bounds 为零时（视图尚未布局），用 1x1 兜底
        let bounds = anchor.bounds.isEmpty
            ? NSRect(x: 0, y: 0, width: 1, height: 1)
            : anchor.bounds

        let contentSize = NSSize(width: 320, height: 360)
        let panelOrigin = calculatePanelOrigin(
            anchor: anchor, bounds: bounds, contentSize: contentSize
        )

        let newPanel = makePanel(
            contentSize: contentSize, hosting: hosting, panelOrigin: panelOrigin
        )

        // 先赋值 panel 再 makeKeyAndOrderFront：
        // makeKeyAndOrderFront 会同步触发 quick paste panel 的 didResignKey，
        // 此时 QuickPastePanelController 需要通过 TagPickerPresenter.isShowing
        // 判断是否因 picker 抢占 key 而失焦，避免误关闭快速粘贴面板。
        panel = newPanel
        newPanel.makeKeyAndOrderFront(nil)
        newPanel.orderFrontRegardless()
        newPanel.contentView?.layoutSubtreeIfNeeded()

        NSLog("[DIAG] TagPickerPresenter.show: panel.isVisible=\(newPanel.isVisible)")
    }

    /// 计算 picker 窗口在屏幕上的位置（锚点正下方）。
    private func calculatePanelOrigin(
        anchor: NSView, bounds: NSRect, contentSize: NSSize
    ) -> NSPoint
    {
        let boundsInWindow = anchor.convert(bounds, to: nil)
        let boundsInScreen = anchor.window?.convertToScreen(boundsInWindow) ?? boundsInWindow
        NSLog("[DIAG] TagPickerPresenter.show: bounds=\(bounds)")
        return NSPoint(
            x: boundsInScreen.origin.x,
            y: boundsInScreen.origin.y - contentSize.height
        )
    }

    /// 创建 NSPanel 并配置 hosting view 布局。
    private func makePanel(
        contentSize: NSSize, hosting: NSHostingController<TagPickerView>, panelOrigin: NSPoint
    ) -> NSPanel
    {
        let newPanel = NSPanel(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        newPanel.titleVisibility = .hidden
        newPanel.titlebarAppearsTransparent = true
        newPanel.isMovableByWindowBackground = false
        newPanel.level = .floating
        newPanel.contentViewController = hosting
        // 确保 hosting view 填满 panel content area，避免 ScrollView 高度为 0
        hosting.view.frame = NSRect(origin: .zero, size: contentSize)
        hosting.view.autoresizingMask = [.width, .height]
        newPanel.setFrameOrigin(panelOrigin)
        return newPanel
    }

    /// 关闭标签选择器（若正在展示）。
    func close()
    {
        if let panel = panel, panel.isVisible
        {
            panel.orderOut(nil)
        }
        panel = nil
    }
}

/// F1.14：标签选择器锚点视图。
///
/// 一个隐形的 `NSView`，作为 `TagPickerPresenter` 的锚点。通过 `NSViewRepresentable`
/// 嵌入 SwiftUI 视图树，在 `makeNSView` 中把当前 `NSView` 引用回传给调用方。
///
/// 关键：锚点 view 必须不接收鼠标事件（`hitTest` 返回 nil），否则会覆盖
/// 同层级的 SwiftUI Button 命中区，导致 Button 不可点击。
///
/// 用法：
/// ```swift
/// ClipTagStripView(...)
///     .background(
///         TagPickerAnchor { anchorView in
///             self.anchorHolder.view = anchorView
///         }
///     )
/// ```
struct TagPickerAnchor: NSViewRepresentable
{
    /// 当 NSView 创建后，回调给调用方持有。
    let onAnchorReady: (NSView) -> Void

    func makeNSView(context: Context) -> NSView
    {
        let view = NonHitTestView()
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLog("[DIAG] TagPickerAnchor.makeNSView: calling onAnchorReady")
        onAnchorReady(view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context)
    {
        // 无需更新；anchor view 在 makeNSView 中已回传
    }
}

/// 不参与命中测试的 NSView 子类。
///
/// `hitTest(_:)` 返回 nil 表示本 view 不接收鼠标事件，事件穿透到下层视图。
/// 用于 `TagPickerAnchor`，确保锚点 view 不拦截 SwiftUI Button 的点击。
private final class NonHitTestView: NSView
{
    override func hitTest(_ point: NSPoint) -> NSView?
    {
        nil
    }
}
