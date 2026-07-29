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
    /// - Parameters:
    ///   - clips: 注入的剪贴项列表（UITEST 模式下为 `ClipTestData.previewClips`）
    ///   - suppressor: 共享的自我写入抑制器。UITEST_FORCE_NO_PERMISSION 路径下注入到
    ///     ClipboardWriter，使自我写入抑制行为与生产装配一致。
    ///   - clipToucher: 共享的剪贴项置顶器。UITEST_FORCE_NO_PERMISSION 路径下注入到
    ///     PasteCoordinator，使双击粘贴后置顶行为与生产装配一致。
    static func show(
        clips: [ClipItem],
        suppressor: SelfWriteSuppressor? = nil,
        clipToucher: ClipTouching? = nil,
        tagStore: TagStore? = nil
    )
    {
        let window = makeWindow()
        let viewModel = UnifiedPastePanelViewModel(clips: clips)
        // UITEST 模式下注入 Esc 回调，模拟 NSPopover 的关闭行为
        viewModel.onEscPressed = { [weak window] in
            window?.close()
        }
        // F1.11 Bug Fix：「退出」按钮在 UITEST 模式下不真的调用 NSApp.terminate
        // （会终止测试进程），改为关闭预览窗口模拟「退出」行为，
        // 使 XCUITest 能通过 searchField.waitForExistence 验证按钮被触发
        viewModel.onExitApp = { [weak window] in
            window?.close()
        }
        configurePasteTrigger(
            viewModel: viewModel,
            window: window,
            suppressor: suppressor,
            clipToucher: clipToucher
        )

        window.contentViewController = NSHostingController(
            rootView: UnifiedPastePanelView(
                viewModel: viewModel,
                showsBottomBar: true,
                accessibilityPrefix: "popover",
                tagStore: tagStore
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
        //
        // F1.11 Phase 3 任务 8 修复：保存监听器 token，在 popover 窗口关闭时移除监听器，
        // 避免 close 后延迟触发的 didBecomeKey 事件导致时序竞争（test02/test04 flaky 根因）。
        var keyWindowObserver: NSObjectProtocol?
        keyWindowObserver = NotificationCenter.default.addObserver(
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

        // 监听 popover 窗口关闭事件，移除 didBecomeKey 监听器。
        // 无论是 Esc 键、底部工具栏按钮点击、还是双击粘贴触发 close，都会通过此监听器清理。
        // 避免窗口关闭后仍有延迟的 didBecomeKey 事件触发监听器，导致主窗口被误 orderOut。
        // willClose 监听器本身无需移除：窗口关闭后不会再触发 willClose 事件。
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { _ in
            if let observer = keyWindowObserver
            {
                NotificationCenter.default.removeObserver(observer)
                keyWindowObserver = nil
            }
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
        window: NSPanel,
        suppressor: SelfWriteSuppressor?,
        clipToucher: ClipTouching?
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
            // F1.11 Bug 3：UITEST_FORCE_NO_PERMISSION 路径同样注入共享 suppressor，
            // 使 ClipboardWriter 写入与 PasteboardWatcher 行为一致。
            // F1.11 Bug 4：同步注入 clipToucher，使双击粘贴后置顶行为与生产一致。
            let coordinator = PasteCoordinator(
                permissionChecker: permissionChecker,
                clipboardWriter: ClipboardWriter(suppressor: suppressor),
                panelCloser: NoOpPanelCloser(),
                overlayShower: overlayShower,
                clipToucher: clipToucher
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
