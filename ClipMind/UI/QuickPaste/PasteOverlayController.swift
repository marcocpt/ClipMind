import AppKit
import Foundation
import SwiftUI

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
///
/// 标记为 @MainActor 与实现类 PasteOverlayController 保持一致，
/// 避免 Swift 5 模式下协议方法 actor 隔离不一致导致的运行时调度问题
/// （Swift 6 模式下不一致会直接报错）。
@MainActor
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

        let isUITesting = CommandLine.arguments.contains("--UITEST_SHOW_MAIN_WINDOW")
        let panel = makePanel()
        self.panel = panel

        let position = screenLocator.locatePosition()
        panel.setFrameOrigin(position)
        // UI 测试模式：使用 makeKeyAndOrderFront 使浮层成为 key window，
        // XCUITest 需要元素在 key window 中才能可靠检测。
        // 生产模式：使用 orderFrontRegardless 不要求 app 处于活动状态，
        // 浮层为 .nonactivatingPanel 不抢夺前台应用焦点。
        if isUITesting
        {
            // UI 测试模式：先激活应用再显示浮层，确保浮层能成为 key window
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
        } else { panel.orderFrontRegardless() }
        isOverlayVisible = true

        // UI 测试模式：通过 UserDefaults 记录浮层状态，供 XCUITest 通过 CFPreferences 轮询读取。
        // 必须调用 synchronize() 确保 plist 文件立即更新，
        // 否则 XCUITest 进程中的 CFPreferencesGetAppBooleanValue 读到旧值。
        if isUITesting
        {
            UserDefaults.standard.set(true, forKey: "UITest_overlayVisible")
            UserDefaults.standard.synchronize()
        }

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
        // UI 测试模式：通过 UserDefaults 记录浮层状态
        // 必须调用 synchronize() 确保 plist 文件立即更新
        let isUITesting = CommandLine.arguments.contains("--UITEST_SHOW_MAIN_WINDOW")
        if isUITesting
        {
            UserDefaults.standard.set(false, forKey: "UITest_overlayVisible")
            UserDefaults.standard.synchronize()
        }
        LogCategory.ui.info("Paste overlay hidden")
    }

    // MARK: - 测试辅助

    /// 仅供单元测试读取浮层文案。
    var overlayTextForTesting: String
    {
        Self.overlayMessage
    }

    // MARK: - 私有

    private func makePanel() -> NSPanel
    {
        // UI 测试模式下使用普通窗口样式（移除 .nonactivatingPanel），
        // 使 XCUITest 能可靠检测浮层元素。生产环境保留 .nonactivatingPanel
        // 不抢夺前台应用焦点。
        let isUITesting = CommandLine.arguments.contains("--UITEST_SHOW_MAIN_WINDOW")
        var styleMask: NSWindow.StyleMask = [.titled, .fullSizeContentView]
        if !isUITesting
        {
            styleMask.insert(.nonactivatingPanel)
        }

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: Self.overlaySize),
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        // 为 NSPanel 本身设置 accessibilityIdentifier，
        // NSHostingView 内的 SwiftUI accessibilityIdentifier 在 XCUITest 中不可靠检测
        panel.setAccessibilityIdentifier("pasteOverlayPanel")
        panel.setAccessibilityLabel(Self.overlayMessage)

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
