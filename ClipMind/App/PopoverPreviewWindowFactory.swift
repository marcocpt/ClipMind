import AppKit
import SwiftUI

/// 菜单栏弹窗预览窗口工厂（F1.11 Phase 2）。
///
/// 在 UITEST 模式下（`--UITEST_POPOVER_WINDOW`）创建独立 `NSPanel` 承载 `UnifiedPastePanelView`，
/// 使 XCUITest 能稳定定位元素。使用 `NSPanel`（与 F1.9 快捷键面板一致的窗口类型），
/// 避免 `NSWindow` 的 `.closable` styleMask 拦截 Esc 键导致 `onEscPressed` 不触发。
@MainActor
enum PopoverPreviewWindowFactory
{
    /// 创建并显示菜单栏弹窗预览窗口。
    /// - Parameter clips: 注入的剪贴项列表（UITEST 模式下为 `ClipTestData.previewClips`）
    static func show(clips: [ClipItem])
    {
        let window = makeWindow()
        let viewModel = UnifiedPastePanelViewModel(clips: clips)
        // UITEST 模式下注入 Esc 回调，模拟 NSPopover 的关闭行为
        viewModel.onEscPressed = { [weak window] in
            window?.close()
        }
        configurePasteTrigger(viewModel: viewModel, window: window)

        window.contentViewController = NSHostingController(
            rootView: UnifiedPastePanelView(
                viewModel: viewModel,
                showsBottomBar: true,
                accessibilityPrefix: "popover"
            )
        )
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // 关闭 SwiftUI WindowGroup 创建的主窗口，避免主窗口抢占 key window 状态
        // 导致 XCUITest 的 click/typeKey 操作因「应用未在前台」失败。
        // 主窗口在 applicationDidFinishLaunching 之后由 SwiftUI 创建，监听
        // NSWindow.didBecomeKey 通知：任何其他窗口成为 key 时立即关闭并让 popover 重新成为 key。
        // 使用 orderOut 而非 close，避免触发 NSApplication.terminate。
        // 防护：仅当 popover 窗口仍然可见时才处理，避免 popover 关闭后监听器触发循环。
        // 监听持续整个测试过程（应用退出时自动清理）。
        NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { [weak window] note in
            guard let becameKey = note.object as? NSWindow, becameKey !== window else { return }
            // 仅当 popover 窗口仍然可见时才关闭其他窗口，避免 popover 关闭后触发循环
            guard window?.isVisible == true else { return }
            becameKey.orderOut(nil)
            window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    /// 创建菜单栏弹窗预览使用的 NSPanel（与 F1.9 快捷键面板一致的窗口类型）。
    private static func makeWindow() -> NSPanel
    {
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 480),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isFloatingPanel = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.hidesOnDeactivate = false
        window.center()
        return window
    }

    /// 配置 `onPasteTriggered` 回调。
    ///
    /// - `--UITEST_FORCE_NO_PERMISSION`：注入真实 PasteCoordinator，验证无权限降级浮层（AC-F1.11-10）。
    ///   使用 `NoOpPanelCloser` 避免面板关闭，使 XCUITest 能读取 `popoverTestTriggeredClipId`。
    /// - 默认：不接入 PasteCoordinator，仅模拟「粘贴触发后关闭面板」信号。
    private static func configurePasteTrigger(
        viewModel: UnifiedPastePanelViewModel,
        window: NSPanel
    )
    {
        if CommandLine.arguments.contains("--UITEST_FORCE_NO_PERMISSION")
        {
            let permissionChecker = PopoverUITestNoPermissionChecker()
            let overlayShower = PasteOverlayController(
                consumerWatcher: ClipboardConsumerWatcher(),
                timerScheduler: OverlayTimer(),
                settings: QuickPasteSettings(),
                screenLocator: ScreenCenterOverlayLocator()
            )
            let coordinator = PasteCoordinator(
                permissionChecker: permissionChecker,
                clipboardWriter: ClipboardWriter(),
                panelCloser: NoOpPanelCloser(),
                overlayShower: overlayShower
            )
            viewModel.onPasteTriggered = { clip in
                coordinator.handlePaste(clip: clip)
            }
        } else {
            viewModel.onPasteTriggered = { [weak window] _ in
                window?.close()
            }
        }
    }
}

// MARK: - UI 测试辅助

/// UI 测试专用：始终返回无权限的权限检测器（菜单栏弹窗场景）。
///
/// 与 `QuickPasteAssembly.UITestNoPermissionChecker` 行为一致，但独立声明以避免
/// 访问级别冲突（QuickPasteAssembly 中的为 `private`）。
private final class PopoverUITestNoPermissionChecker: PastePermissionChecking
{
    func isAccessibilityGranted() -> Bool { false }
}

/// UI 测试专用：不执行任何操作的面板关闭器。
///
/// 用于 `--UITEST_FORCE_NO_PERMISSION` 模式下，使 PasteCoordinator 执行权限检查与浮层显示，
/// 但不关闭弹窗，便于 XCUITest 读取 `popoverTestTriggeredClipId` 等测试元素。
private final class NoOpPanelCloser: PanelClosing
{
    var isPanelVisible: Bool { true }

    func closePanel() {}
}
