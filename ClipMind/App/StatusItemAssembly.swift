import AppKit

// MARK: - 状态栏图标控制器装配（F1.11 Phase 1）

extension AppDelegate
{
    /// 初始化状态栏图标控制器（F1.11 Phase 1）。
    ///
    /// 注入 `EncryptedStore` 数据源与独立的 `PasteCoordinator` 实例（设计文档第 10.4 节推荐方案：
    /// 每控制器各持有一个 PasteCoordinator 实例，避免共享状态风险）。
    /// 必须在 `setupQuickPastePanelController` 之后调用，以复用 `ScreenCenterOverlayLocator`
    /// 等同款依赖构造逻辑。
    @MainActor
    func setupStatusItemController()
    {
        guard let store = try? EncryptedStore()
        else
        {
            LogCategory.app.error("StatusItemController setup failed: EncryptedStore init failed")
            return
        }

        let statusItemControllerInstance = StatusItemController()
        statusItemController = statusItemControllerInstance

        // 构造菜单栏弹窗专用的 PasteCoordinator（panelCloser 绑定到 StatusItemController）
        let permissionChecker = SystemPastePermissionChecker()
        let overlayShower = PasteOverlayController(
            consumerWatcher: ClipboardConsumerWatcher(),
            timerScheduler: OverlayTimer(),
            settings: QuickPasteSettings(),
            screenLocator: ScreenCenterOverlayLocator()
        )
        let popoverCoordinator = PasteCoordinator(
            permissionChecker: permissionChecker,
            clipboardWriter: ClipboardWriter(),
            panelCloser: statusItemControllerInstance,
            overlayShower: overlayShower
        )

        statusItemControllerInstance.setup(
            encryptedStore: store,
            pasteCoordinator: popoverCoordinator
        )
    }
}
