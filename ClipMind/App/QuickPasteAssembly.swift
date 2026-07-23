import AppKit
import SwiftUI

// MARK: - 快速粘贴面板装配（F1.9 Phase 3）

extension AppDelegate
{
    /// 初始化快速粘贴面板控制器与粘贴流程协调器（F1.9）。
    @MainActor
    func setupQuickPastePanelController()
    {
        let locator = ScreenCenterPanelLocator()
        let panelController = QuickPastePanelController(screenLocator: locator)
        quickPastePanelController = panelController

        // UI 测试启动参数：强制无权限（避免依赖真实辅助功能权限状态）
        let permissionChecker: PastePermissionChecking
        if CommandLine.arguments.contains("--UITEST_FORCE_NO_PERMISSION") {
            permissionChecker = UITestNoPermissionChecker()
        } else {
            permissionChecker = SystemPastePermissionChecker()
        }

        // UI 测试启动参数：超时 1 秒加速
        let settings: QuickPasteSettings
        if CommandLine.arguments.contains("--UITEST_OVERLAY_TIMEOUT_1S") {
            let testDefaults = UserDefaults.standard
            testDefaults.set(1.0, forKey: "F1.9.quickPaste.overlayDuration")
            settings = QuickPasteSettings(defaults: testDefaults)
        } else {
            settings = QuickPasteSettings()
        }

        // UI 测试启动参数：1 秒后模拟消费
        let consumerWatcher: ClipboardConsumerWatcherProtocol
        if CommandLine.arguments.contains("--UITEST_SIMULATE_CONSUMPTION_AFTER_1S") {
            consumerWatcher = UITestSimulatedConsumerWatcher(delay: 1.0)
        } else {
            consumerWatcher = ClipboardConsumerWatcher()
        }

        let overlayLocator = ScreenCenterOverlayLocator()
        let overlayController = PasteOverlayController(
            consumerWatcher: consumerWatcher,
            timerScheduler: OverlayTimer(),
            settings: settings,
            screenLocator: overlayLocator
        )

        let coordinator = PasteCoordinator(
            permissionChecker: permissionChecker,
            clipboardWriter: ClipboardWriter(),
            panelCloser: panelController,
            overlayShower: overlayController
        )
        pasteCoordinator = coordinator

        // UI 测试启动参数：直接显示面板
        if CommandLine.arguments.contains("--UITEST_QUICK_PASTE_PANEL") {
            if CommandLine.arguments.contains("--UITEST_PREPOPULATE_IMAGE_AND_FILEPATH") {
                prepopulateImageAndFilePathForTesting()
            }
            let contentController = makeQuickPasteContentController(coordinator: coordinator)
            panelController.showPanel(contentController: contentController)
        }
    }

    /// 创建快速粘贴面板内容视图控制器。
    @MainActor
    func makeQuickPasteContentController(coordinator: PasteCoordinator) -> NSViewController
    {
        let clips = loadClipsForQuickPaste()
        let viewModel = QuickPasteViewModel(clips: clips)
        viewModel.onPasteTriggered = { clip in
            coordinator.handlePaste(clip: clip)
        }
        viewModel.onEscPressed = { [weak self] in
            self?.quickPastePanelController?.handleEscKey()
        }
        let view = QuickPasteView(viewModel: viewModel)
        return NSHostingController(rootView: view)
    }

    /// 加载剪贴项列表（快速粘贴面板数据源）。
    func loadClipsForQuickPaste() -> [ClipItem]
    {
        do {
            let store = try EncryptedStore()
            return Array(try store.loadAll().prefix(50))
        } catch {
            LogCategory.storage.error("加载快速粘贴面板数据失败: \(error.localizedDescription)")
            return []
        }
    }

    /// F1.9：接收全局快捷键通知，呼出快速粘贴面板。
    @MainActor
    @objc func handleOpenQuickPaste()
    {
        guard let coordinator = pasteCoordinator else { return }
        let contentController = makeQuickPasteContentController(coordinator: coordinator)
        quickPastePanelController?.showPanel(contentController: contentController)
    }

    /// UI 测试专用：预置图片+文件路径数据到 EncryptedStore。
    func prepopulateImageAndFilePathForTesting()
    {
        do {
            let store = try EncryptedStore()
            let imageClip = ClipItem.makeImage(
                Data([0x89, 0x50, 0x4E, 0x47]),
                contentType: .other,
                sourceApp: "com.test",
                sourceAppName: "Test"
            )
            let filePathClip = ClipItem.makeFilePath(
                [URL(fileURLWithPath: "/tmp/test.txt")],
                contentType: .other,
                sourceApp: "com.test",
                sourceAppName: "Test"
            )
            let textClip = ClipItem.makeText(
                "文本内容",
                contentType: .other,
                sourceApp: "com.test",
                sourceAppName: "Test"
            )
            try store.save(imageClip)
            try store.save(filePathClip)
            try store.save(textClip)
            NotificationCenter.default.post(
                name: ClipCaptureService.clipDidUpdateNotification,
                object: nil
            )
        } catch {
            LogCategory.storage.error("预置图片/文件路径测试数据失败: \(error.localizedDescription)")
        }
    }
}

// MARK: - 屏幕中央定位器

/// 屏幕中央面板定位器（生产环境无权限路径使用）。
/// Phase 4 会根据权限状态切换为 CaretPanelLocator。
private final class ScreenCenterPanelLocator: PanelScreenLocating
{
    func locatePosition(lastClosedPosition: NSPoint?) -> NSPoint
    {
        // 优先使用上次关闭位置（若在屏幕可视范围内）
        if let last = lastClosedPosition,
           let screenFrame = NSScreen.main?.frame {
            let panelRect = NSRect(
                origin: last,
                size: QuickPastePanelController.panelSize
            )
            if screenFrame.contains(panelRect) {
                return last
            }
        }
        // 降级到屏幕中央
        let screenFrame = NSScreen.main?.frame ?? .zero
        return NSPoint(
            x: screenFrame.midX - QuickPastePanelController.panelSize.width / 2.0,
            y: screenFrame.midY - QuickPastePanelController.panelSize.height / 2.0
        )
    }
}

/// 屏幕中央浮层定位器（降级浮层使用）。
private final class ScreenCenterOverlayLocator: OverlayScreenLocating
{
    func locatePosition() -> NSPoint
    {
        let screenFrame = NSScreen.main?.frame ?? .zero
        return NSPoint(
            x: screenFrame.midX - 110,
            y: screenFrame.midY - 30
        )
    }
}

// MARK: - UI 测试辅助

/// UI 测试专用：始终返回无权限的权限检测器。
private final class UITestNoPermissionChecker: PastePermissionChecking
{
    func isAccessibilityGranted() -> Bool { false }
}

/// UI 测试专用：延迟后模拟消费的监听器。
private final class UITestSimulatedConsumerWatcher: ClipboardConsumerWatcherProtocol
{
    private let delay: TimeInterval
    private var workItem: DispatchWorkItem?

    init(delay: TimeInterval) {
        self.delay = delay
    }

    func start(onConsumed: @escaping () -> Void) {
        let workItem = DispatchWorkItem {
            onConsumed()
        }
        self.workItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    func stop() {
        workItem?.cancel()
        workItem = nil
    }
}
