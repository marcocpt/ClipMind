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
        // F1.11 Bug 3：注入共享的 selfWriteSuppressor，使菜单栏弹窗双击粘贴路径
        // 也参与自我写入抑制，避免列表重复入库。
        // F1.11 Bug 4：注入共享的 clipToucher，使菜单栏弹窗双击粘贴后置顶被粘贴项。
        let permissionChecker = SystemPastePermissionChecker()
        let overlayShower = PasteOverlayController(
            consumerWatcher: ClipboardConsumerWatcher(),
            timerScheduler: OverlayTimer(),
            settings: QuickPasteSettings(),
            screenLocator: ScreenCenterOverlayLocator()
        )
        let popoverCoordinator = PasteCoordinator(
            permissionChecker: permissionChecker,
            clipboardWriter: ClipboardWriter(suppressor: selfWriteSuppressor),
            panelCloser: statusItemControllerInstance,
            overlayShower: overlayShower,
            clipToucher: clipToucher
        )

        statusItemControllerInstance.setup(
            encryptedStore: store,
            pasteCoordinator: popoverCoordinator,
            tagStore: tagStore
        )
    }
}
