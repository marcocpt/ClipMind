import AppKit
import Foundation
import SwiftUI

/// 浮层可见性变更通知名（UI 测试 test hook 用）。
///
/// NSPanel(.nonactivatingPanel) 在 CI 中无法被 XCUITest 可靠检测，
/// 通过此通知把浮层可见状态广播到主窗口的 test hook 元素，供 UI 测试验证。
/// 生产代码不依赖此通知。
extension Notification.Name
{
    static let pasteOverlayVisibilityChanged = Notification.Name("F1.9.quickPaste.overlayVisibilityChanged")
}

/// 浮层定位协议（依赖注入，便于测试 mock）。
protocol OverlayScreenLocating: AnyObject
{
    /// 计算浮层显示位置（左下角原点）。
    func locatePosition() -> NSPoint
}

/// 剪贴板消费监听协议（抽象 ClipboardConsumerWatcher 便于测试 mock）。
protocol ClipboardConsumerWatcherProtocol: AnyObject
{
    /// 启动消费监听。
    /// - Parameter onConsumed: 剪贴板被消费时的回调
    func start(onConsumed: @escaping () -> Void)

    /// 停止消费监听。
    func stop()
}

/// 使 ClipboardConsumerWatcher 遵循协议。
extension ClipboardConsumerWatcher: ClipboardConsumerWatcherProtocol {}

/// 浮层超时计时协议（依赖注入，便于测试 mock，避免等待真实超时）。
protocol OverlayTimerScheduling: AnyObject
{
    /// 调度超时回调。
    /// - Parameters:
    ///   - duration: 超时时长（秒）
    ///   - handler: 超时触发的回调
    func scheduleTimeout(after duration: TimeInterval, handler: @escaping () -> Void)

    /// 取消已调度的超时。
    func cancelTimeout()
}

/// 浮层超时计时器默认实现（使用 DispatchSourceTimer，不使用 sleep）。
final class OverlayTimer: OverlayTimerScheduling
{
    private var timer: DispatchSourceTimer?
    private var handler: (() -> Void)?

    func scheduleTimeout(after duration: TimeInterval, handler: @escaping () -> Void)
    {
        cancelTimeout()
        self.handler = handler
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + duration)
        timer.setEventHandler { [weak self] in
            let callback = self?.handler
            self?.cancelTimeout()
            callback?()
        }
        timer.resume()
        self.timer = timer
    }

    func cancelTimeout()
    {
        timer?.cancel()
        timer = nil
        handler = nil
    }
}

/// 浮层显示协议（供 PasteCoordinator 注入，便于测试 mock）。
protocol OverlayShowing: AnyObject
{
    /// 显示降级浮层。
    func showOverlay()

    /// 隐藏降级浮层（若已隐藏则忽略）。
    func hideOverlay()
}

/// 降级浮层控制器。
///
/// 设计文档第 3.4 节 + 第 5.2 节状态机。
/// 职责：显示"已复制，按 Cmd+V 粘贴"通用文案 + 启动消费监听 + 启动超时计时器。
/// 两条消失路径（消费/超时）互斥，先触发者生效，另一条路径被取消。
/// 浮层使用 NSPanel(.nonactivatingPanel) 不抢夺前台应用焦点。
/// 文案硬编码，不显示剪贴板原文（NFR-003 安全性）。
@MainActor
final class PasteOverlayController: OverlayShowing
{
    /// 浮层通用文案（硬编码，不显示剪贴板原文）。
    static let overlayMessage = "已复制，按 Cmd+V 粘贴"

    /// 浮层固定尺寸。
    private static let overlaySize = NSSize(width: 220, height: 60)

    /// 浮层可见性通知 userInfo 键（test hook 用）。
    static let visibilityUserInfoKey = "isOverlayVisible"

    private let consumerWatcher: ClipboardConsumerWatcherProtocol
    private let timerScheduler: OverlayTimerScheduling
    private let settings: QuickPasteSettings
    private let screenLocator: OverlayScreenLocating

    private var panel: NSPanel?
    private(set) var isOverlayVisible = false

    init(
        consumerWatcher: ClipboardConsumerWatcherProtocol,
        timerScheduler: OverlayTimerScheduling,
        settings: QuickPasteSettings,
        screenLocator: OverlayScreenLocating
    )
    {
        self.consumerWatcher = consumerWatcher
        self.timerScheduler = timerScheduler
        self.settings = settings
        self.screenLocator = screenLocator
    }

    // MARK: - OverlayShowing

    func showOverlay()
    {
        guard !isOverlayVisible else {
            LogCategory.ui.info("Paste overlay already visible, ignore show request")
            return
        }

        let panel = makePanel()
        self.panel = panel

        let position = screenLocator.locatePosition()
        panel.setFrameOrigin(position)
        // 使用 orderFrontRegardless 而非 makeKeyAndOrderFront：浮层为非激活面板，
        // 在面板关闭后 app 可能失焦，makeKeyAndOrderFront 可能无法可靠显示浮层。
        // orderFrontRegardless 不要求 app 处于活动状态，CI 环境更可靠。
        panel.orderFrontRegardless()
        isOverlayVisible = true

        // 启动消费监听
        consumerWatcher.start { [weak self] in
            self?.hideOverlay()
        }

        // 启动超时计时器（时长从 QuickPasteSettings 读取）
        let duration = settings.loadOverlayDuration()
        timerScheduler.scheduleTimeout(after: duration) { [weak self] in
            self?.hideOverlay()
        }

        LogCategory.ui.info("Paste overlay shown, timeout: \(duration)s")
        postVisibilityChangedNotification(visible: true)
    }

    func hideOverlay()
    {
        guard isOverlayVisible else { return }

        // 互斥：取消另一条消失路径
        consumerWatcher.stop()
        timerScheduler.cancelTimeout()

        panel?.orderOut(nil)
        panel = nil
        isOverlayVisible = false
        LogCategory.ui.info("Paste overlay hidden")
        postVisibilityChangedNotification(visible: false)
    }

    // MARK: - 测试辅助

    /// 仅供单元测试读取浮层文案。
    var overlayTextForTesting: String
    {
        Self.overlayMessage
    }

    // MARK: - 私有

    /// 广播浮层可见性变更通知（test hook 用，供主窗口 test 元素反映状态）。
    private func postVisibilityChangedNotification(visible: Bool)
    {
        NotificationCenter.default.post(
            name: .pasteOverlayVisibilityChanged,
            object: nil,
            userInfo: [Self.visibilityUserInfoKey: visible]
        )
    }

    private func makePanel() -> NSPanel
    {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: Self.overlaySize),
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

        let hostingView = NSHostingView(rootView: OverlayContentView(text: Self.overlayMessage))
        panel.contentView = hostingView
        return panel
    }
}

/// 浮层内容视图（SwiftUI）。
private struct OverlayContentView: View
{
    let text: String

    var body: some View
    {
        HStack(spacing: 8)
        {
            Image(systemName: "doc.on.clipboard")
                .foregroundColor(.accentColor)
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
        .accessibilityIdentifier("pasteOverlayMessage")
    }
}
