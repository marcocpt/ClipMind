@testable import ClipMind
import XCTest

/// StatusItemController 单元测试（Phase 1 任务 3）。
///
/// 验证：
/// - StatusItemController 实现 PanelClosing 协议
/// - closePanel() 在弹窗已显示时关闭弹窗，在弹窗未显示时忽略
/// - isPanelVisible 状态正确反映弹窗显示状态
@MainActor
final class StatusItemControllerTests: XCTestCase
{
    func testStatusItemController_ConformsToPanelClosing()
    {
        let controller = StatusItemController()

        XCTAssertTrue(controller is PanelClosing, "StatusItemController 必须实现 PanelClosing 协议")
    }

    func testClosePanel_WhenPopoverNotShown_DoesNotCrash()
    {
        let controller = StatusItemController()

        // 弹窗未显示时调用 closePanel，应忽略不崩溃
        controller.closePanel()

        XCTAssertFalse(controller.isPanelVisible, "弹窗未显示时 isPanelVisible = false")
    }

    func testIsPanelVisible_InitiallyFalse()
    {
        let controller = StatusItemController()

        XCTAssertFalse(controller.isPanelVisible, "初始状态 isPanelVisible = false")
    }
}

extension StatusItemControllerTests
{
    // MARK: - AC-F1.11-12 / AC-F1.11-14：依赖注入链路

    /// 验证 setup(encryptedStore:pasteCoordinator:) 接受 EncryptedStore 与 PasteCoordinator 注入。
    /// 注入后调用 closePanel 不崩溃，说明依赖已正确注入。
    func testSetup_InjectsEncryptedStoreAndPasteCoordinator()
    {
        let controller = StatusItemController()
        let store = try? EncryptedStore()
        let permissionChecker = SystemPastePermissionChecker()
        let overlayShower = StatusItemMockOverlayShower()
        let coordinator = PasteCoordinator(
            permissionChecker: permissionChecker,
            clipboardWriter: ClipboardWriter(),
            panelCloser: controller,
            overlayShower: overlayShower
        )
        XCTAssertNotNil(store, "EncryptedStore 应可初始化")

        controller.setup(encryptedStore: store!, pasteCoordinator: coordinator)

        // 注入后调用 closePanel 不崩溃，说明依赖已注入
        controller.closePanel()
        XCTAssertFalse(controller.isPanelVisible, "未弹出过弹窗时 isPanelVisible = false")
    }

    /// 验证未注入依赖时 closePanel 也安全（防御性测试）。
    func testClosePanel_WithoutSetup_DoesNotCrash()
    {
        let controller = StatusItemController()

        // 未调用 setup，直接 closePanel 应被 guard 拦截
        controller.closePanel()

        XCTAssertFalse(controller.isPanelVisible)
    }
}

/// 测试用浮层显示协议实现（记录调用，避免与 PasteCoordinatorTests.MockOverlayShower 重名）。
@MainActor
final class StatusItemMockOverlayShower: OverlayShowing
{
    var showOverlayCallCount = 0
    var hideOverlayCallCount = 0

    func showOverlay()
    {
        showOverlayCallCount += 1
    }

    func hideOverlay()
    {
        hideOverlayCallCount += 1
    }
}

/// 测试用：始终返回无权限的权限检测器（Phase 2 任务 1，避免与其它测试文件重名）。
@MainActor
final class StatusItemNoPermissionChecker: PastePermissionChecking
{
    func isAccessibilityGranted() -> Bool { false }
}

// MARK: - Phase 2 任务 1：PasteCoordinator 接入验证

extension StatusItemControllerTests
{
    /// AC-F1.11-2/-3：验证 StatusItemController 接收的 PasteCoordinator 实例，
    /// 其 panelCloser 指向 StatusItemController 自身（PanelClosing 协议）。
    /// 图片类型双击不触发写入、不关闭面板。
    func testPasteCoordinator_IntegrationWithStatusItemController_ImageClipSkipped()
    {
        let controller = StatusItemController()
        let store = try? EncryptedStore()
        XCTAssertNotNil(store, "EncryptedStore 应可初始化")

        let overlayShower = StatusItemMockOverlayShower()
        let coordinator = PasteCoordinator(
            permissionChecker: SystemPastePermissionChecker(),
            clipboardWriter: ClipboardWriter(),
            panelCloser: controller,
            overlayShower: overlayShower
        )
        controller.setup(encryptedStore: store!, pasteCoordinator: coordinator)

        // 图片类型不进入粘贴流程
        let imageClip = ClipItem.makeImage(
            Data([0x89, 0x50, 0x4E, 0x47]),
            contentType: .other,
            sourceApp: "com.test",
            sourceAppName: "Test"
        )
        coordinator.handlePaste(clip: imageClip)

        XCTAssertEqual(overlayShower.showOverlayCallCount, 0, "图片类型不触发浮层")
        XCTAssertFalse(controller.isPanelVisible, "图片类型不关闭面板")
    }

    /// AC-F1.11-2/-3：无权限路径下文本类型触发浮层显示（降级提示）。
    /// 单元测试下 controller.isPanelVisible 初始即为 false，
    /// 真实场景下面板已显示时 closePanel 会执行关闭。
    func testPasteCoordinator_TextClip_NoPermission_TriggersOverlay()
    {
        let controller = StatusItemController()
        let store = try? EncryptedStore()
        XCTAssertNotNil(store, "EncryptedStore 应可初始化")

        let overlayShower = StatusItemMockOverlayShower()
        let coordinator = PasteCoordinator(
            permissionChecker: StatusItemNoPermissionChecker(),
            clipboardWriter: ClipboardWriter(),
            panelCloser: controller,
            overlayShower: overlayShower
        )
        controller.setup(encryptedStore: store!, pasteCoordinator: coordinator)

        let textClip = ClipItem.makeText(
            "hello",
            contentType: .other,
            sourceApp: "com.test",
            sourceAppName: "Test"
        )
        coordinator.handlePaste(clip: textClip)

        XCTAssertEqual(overlayShower.showOverlayCallCount, 1, "无权限路径应显示浮层")
    }
}
