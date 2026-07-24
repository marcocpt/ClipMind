import AppKit
import SwiftUI

/// F2.1.1 Toast 窗口承载模块（设计文档 §3.2、§5.4、D1、D5）。
///
/// 职责：
/// - 创建屏幕级透明窗口（NSPanel `.nonactivatingPanel` + `.floating` level）承载 ToastView
/// - 定位到主屏幕顶部居中（FR-003、AC-09：距顶部 24pt）
/// - 执行进入动画（alpha 0→1 + 从顶部滑入，约 0.2s，FR-005、D5）
/// - 执行退出动画（alpha 1→0 + 反向滑出，约 0.2s，FR-006、D5）
/// - 关闭窗口后立即释放资源（NFR-003）
/// - 保证窗口不抢焦点、不激活 ClipMind 主窗口（FR-011）
///
/// 不负责：决定是否触发 Toast、管理 2 秒计时、决定视觉细节、调用 F2.1 配置
///
/// 访问级别说明：标记为 `open class` + `open func`，允许 ClipMindTests 模块跨模块继承
/// 用于注入测试 Mock（TestToastWindowManager）。
open class ToastWindowManager
{
    /// 窗口距屏幕顶部边距（视觉原型 v1.2 默认 24px，AC-09 允许 16-32pt）
    private static let topInset: CGFloat = 24

    /// 进入/退出动画时长（FR-005、FR-006）
    private static let animationDuration: TimeInterval = 0.2

    /// 滑入/滑出额外偏移量（D5：位置动画偏移，窗口从屏幕顶部之上 10pt 滑入）
    private static let slideOffset: CGFloat = 10

    /// 屏幕不可用时的虚拟布局区域（CI 无头环境兼容）。
    ///
    /// 当 `NSScreen.main` 与 `NSScreen.screens.first` 均为 nil 时使用，
    /// 不应被误认为是真实屏幕几何信息。仅用于计算窗口 frame，使 Toast
    /// 在无头环境下仍能创建并显示，便于 CI 自动验证 UI 行为。
    private static let fallbackScreenBounds = NSRect(x: 0, y: 0, width: 1920, height: 1080)

    private var panel: NSPanel?
    private var hostingController: NSHostingController<ToastView>?

    /// 进入动画完成回调
    public var onDidAppear: (() -> Void)?

    /// 退出动画完成回调
    public var onDidHide: (() -> Void)?

    /// 立即关闭完成回调（替换模式用，无退出动画）
    public var onDidCloseImmediately: (() -> Void)?

    /// 显示失败回调（E4 屏幕查询失败、E5 窗口创建失败，Phase 1 任务 10 使用）
    public var onShowFailed: (() -> Void)?

    /// 窗口当前是否可见（用于测试断言与协调模块查询）
    public private(set) var isWindowVisible: Bool = false

    public init() {}

    /// 当前可用屏幕的可见区域（D1：用于定位 Toast 位置）。
    ///
    /// 优先级：主屏幕 visibleFrame → 任意可用屏幕 visibleFrame → fallback 虚拟布局区域。
    /// 当系统无可用 NSScreen 时（如 CI 无头环境），返回 1920x1080 fallback bounds，
    /// 使 Toast 仍能创建显示，避免触发 `onShowFailed` 而阻塞 UI 自动化测试。
    ///
    /// 标记为 `open` 以便测试重写注入"无屏幕"场景。
    open func currentScreenVisibleFrame() -> NSRect
    {
        if let mainFrame = NSScreen.main?.visibleFrame
        {
            return mainFrame
        }
        if let firstFrame = NSScreen.screens.first?.visibleFrame
        {
            return firstFrame
        }
        LogCategory.toast.logger.warning(
            "ToastWindow: NSScreen unavailable, using fallback bounds"
        )
        return Self.fallbackScreenBounds
    }

    /// 显示 Toast：创建窗口、定位、启动进入动画（alpha + 位置滑入）。
    /// 必须在主线程调用（D6）。
    open func show(fileName: String)
    {
        assertMainThread()
        guard !isWindowVisible else { return }

        let view = ToastView(fileName: fileName)
        let hosting = NSHostingController(rootView: view)
        self.hostingController = hosting

        // 创建透明无焦点窗口（D1：屏幕级浮层，不抢焦点）
        let contentRect = NSRect(x: 0, y: 0, width: 360, height: 40)
        let panel = NSPanel(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary]
        panel.isMovable = false
        panel.contentView = hosting.view

        // 计算目标位置（顶部居中），无可用屏幕时使用 fallback bounds
        let visibleFrame = currentScreenVisibleFrame()
        let bestFrame = panel.frame
        let optimizedWidth = min(bestFrame.width, 360)
        let optimizedHeight = max(bestFrame.height, 40)
        let centerX = visibleFrame.midX - optimizedWidth / 2
        let targetY = visibleFrame.maxY - Self.topInset - optimizedHeight
        let targetFrame = NSRect(x: centerX, y: targetY, width: optimizedWidth, height: optimizedHeight)

        // 初始位置：屏幕顶部之上（滑入起点，对应视觉原型 v1.2 transform: translateY(-100%)）
        let startY = visibleFrame.maxY + Self.slideOffset
        let startFrame = NSRect(x: centerX, y: startY, width: optimizedWidth, height: optimizedHeight)
        panel.setFrame(startFrame, display: true)

        // 进入动画初始状态：透明
        panel.alphaValue = 0
        panel.orderFront(nil)

        self.panel = panel

        // 启动进入动画（D5：alpha 0→1 + setFrame 从顶部滑入到目标位置）
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.animationDuration
            panel.animator().alphaValue = 1
            panel.animator().setFrame(targetFrame, display: true)
        } completionHandler: { [weak self] in
            self?.isWindowVisible = true
            self?.onDidAppear?()
        }
    }

    /// 隐藏 Toast：执行退出动画（alpha + 位置滑出），动画完成后释放窗口资源。
    /// 必须在主线程调用（D6）。
    open func hide(completion: (() -> Void)?)
    {
        assertMainThread()
        guard let panel = panel, isWindowVisible else
        {
            completion?()
            return
        }

        // 计算退出位置：屏幕顶部之上（反向滑出），无屏幕时使用 fallback bounds
        let visibleFrame = currentScreenVisibleFrame()
        let currentFrame = panel.frame
        let endY = visibleFrame.maxY + Self.slideOffset
        let endFrame = NSRect(x: currentFrame.origin.x, y: endY, width: currentFrame.width, height: currentFrame.height)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.animationDuration
            panel.animator().alphaValue = 0
            panel.animator().setFrame(endFrame, display: true)
        } completionHandler: { [weak self] in
            panel.orderOut(nil)
            self?.releaseResources()
            self?.onDidHide?()
            completion?()
        }
    }

    /// 立即关闭窗口（替换模式专用，无退出动画，立即释放资源）。
    /// 必须在主线程调用（D6）。
    open func closeImmediately()
    {
        assertMainThread()
        guard let panel = panel else
        {
            onDidCloseImmediately?()
            return
        }

        panel.orderOut(nil)
        releaseResources()
        onDidCloseImmediately?()
    }

    /// 释放窗口与 hosting 资源（NFR-003）。
    private func releaseResources()
    {
        panel?.contentView = nil
        panel = nil
        hostingController = nil
        isWindowVisible = false
    }

    private func assertMainThread()
    {
        if !Thread.isMainThread
        {
            LogCategory.toast.logger.error(
                "ToastWindow: called on non-main thread"
            )
            assertionFailure("ToastWindowManager must be called on main thread")
        }
    }

    // MARK: - Testing Helpers

    /// 仅供测试断言窗口位置使用，生产代码不调用。
    /// 标记为 public 以支持 ClipMindTests 模块跨模块访问。
    public var currentWindowForTesting: NSWindow?
    {
        panel
    }
}
