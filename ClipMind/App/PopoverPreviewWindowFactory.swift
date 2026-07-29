import AppKit
import SwiftUI

/// 菜单栏弹窗预览窗口工厂（F1.11 Phase 2）。
///
/// 在 UITEST 模式下（`--UITEST_POPOVER_WINDOW`）创建独立 `NSWindow` 承载 `UnifiedPastePanelView`，
/// 使 XCUITest 能稳定定位元素。
///
/// F1.14：窗口类型从 `NSPanel` 改为 `NSWindow`。SwiftUI `.popover()` 在 `NSPanel`
/// 中无法正常显示（macOS 13 已知问题），改用 `NSWindow` 后 `.popover()` 可靠工作。
/// `level = .floating` 保留浮动行为。
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

        // 关闭 SwiftUI WindowGroup 主窗口。
        // 主窗口在 `applicationDidFinishLaunching` 返回后由 SwiftUI 异步创建，
        // 会在屏幕上可见并包含与 popover 窗口相同的 clip 行（数据库加载），
        // 导致 XCUITest 按 accessibility identifier 查找元素时命中主窗口而非 popover 窗口。
        //
        // F1.14：原先用 `didBecomeKeyNotification` 观察器关闭主窗口，但 popover 窗口
        // 已经是 key，主窗口永远不会成为 key，观察器不触发。改为在下一运行循环
        // 直接遍历 `NSApp.windows` 关闭 SwiftUI `AppKitWindow`，确保 popover 窗口
        // 是唯一可见且可交互的窗口。
        closeSwiftUIMainWindow(popoverWindow: window)
    }

    /// 关闭 SwiftUI WindowGroup 创建的主窗口。
    ///
    /// 在下一运行循环遍历 `NSApp.windows`，关闭所有 `SwiftUI.AppKitWindow` 类型的
    /// 窗口（即 WindowGroup 创建的主窗口）。这不影响 NSPanel、NSStatusBarWindow
    /// 或后续 `.popover()` 弹出的标签选择器窗口。
    ///
    /// 使用 `DispatchQueue.main.async` 确保在 SwiftUI 创建主窗口后执行。
    /// 同时安装 `didBecomeKey` 观察器作为后备：如果主窗口在 async 执行前成为 key
    /// （例如系统激活策略导致），观察器会捕获并关闭它。
    private static func closeSwiftUIMainWindow(popoverWindow: NSWindow)
    {
        // 后备观察器：如果主窗口在 async 块执行前成为 key，关闭它
        var keyWindowObserver: NSObjectProtocol?
        keyWindowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { [weak popoverWindow] note in
            guard let becameKey = note.object as? NSWindow,
                  becameKey !== popoverWindow,
                  popoverWindow?.isVisible == true,
                  !(becameKey is NSPanel),
                  becameKey.parent == nil
            else { return }

            becameKey.close()
            popoverWindow?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)

            if let observer = keyWindowObserver
            {
                NotificationCenter.default.removeObserver(observer)
                keyWindowObserver = nil
            }
        }

        // 主要关闭路径：在下一运行循环关闭 SwiftUI AppKitWindow
        DispatchQueue.main.async
        {
            for window in NSApp.windows where window !== popoverWindow
            {
                // 仅关闭 SwiftUI WindowGroup 创建的 AppKitWindow，
                // 不影响 NSPanel（popover/标签选择器）、NSStatusBarWindow 等
                if window.className.contains("AppKitWindow")
                {
                    window.close()
                }
            }
            popoverWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)

            // 主窗口已关闭，移除后备观察器
            if let observer = keyWindowObserver
            {
                NotificationCenter.default.removeObserver(observer)
                keyWindowObserver = nil
            }
        }

        // popover 窗口关闭时移除观察器
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: popoverWindow,
            queue: .main
        ) { _ in
            if let observer = keyWindowObserver
            {
                NotificationCenter.default.removeObserver(observer)
                keyWindowObserver = nil
            }
        }
    }

    /// 创建菜单栏弹窗预览使用的 NSWindow。
    ///
    /// F1.14：从 `NSPanel` 改为 `NSWindow`。SwiftUI `.popover()` 在 `NSPanel` 中
    /// 无法正常显示（macOS 13），`NSWindow` 不存在此问题。
    /// `level = .floating` 保留浮动行为，`styleMask` 不含 `.closable`
    /// 避免 Esc 键被窗口拦截。
    ///
    /// F1.14 修复：styleMask 加入 `.resizable`。SwiftUI `.popover()` 在 macOS 13 上
    /// 要求宿主窗口具备 `.resizable` 才能正确计算 attachment frame 并展示弹出框；
    /// 缺少 `.resizable` 时 popover 内容视图会创建但不会被定位到屏幕上，
    /// 导致 XCUITest 无法定位 `tagPickerTitle`。
    private static func makeWindow() -> NSWindow
    {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 480),
            styleMask: [.titled, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
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
        window: NSWindow,
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
