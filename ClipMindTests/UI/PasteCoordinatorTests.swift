import AppKit
@testable import ClipMind
import Foundation
import XCTest

/// 测试共享调用顺序计数器（供 MockPanelCloser / MockOverlayShower / MockPasteSimulator 共享）。
private var sharedCallSequence = 0

@MainActor
final class PasteCoordinatorTests: XCTestCase
{
    // MARK: - 共享调用顺序计数器（供 MockPanelCloser / MockOverlayShower 共享）

    override func setUp()
    {
        super.setUp()
        sharedCallSequence = 0
    }

    // MARK: - TC-F1.9-7-01 无权限时双击降级粘贴流程

    func testHandlePaste_NoPermission_WritesClipboard_ClosesPanel_ShowsOverlay()
    {
        let permissionChecker = MockPermissionChecker(granted: false)
        let writer = MockClipboardWriter()
        let panel = MockPanelCloser()
        let overlay = MockOverlayShower()
        let coordinator = PasteCoordinator(
            permissionChecker: permissionChecker,
            clipboardWriter: writer,
            panelCloser: panel,
            overlayShower: overlay
        )

        let clip = ClipItem.makeText(
            "测试文本",
            contentType: .other,
            sourceApp: "com.test",
            sourceAppName: "Test"
        )
        coordinator.handlePaste(clip: clip)

        XCTAssertTrue(writer.writeCalled, "无权限时应写入剪贴板")
        XCTAssertEqual(writer.writtenText, "测试文本", "应写入选中文本")
        XCTAssertTrue(panel.closeCalled, "应关闭面板")
        XCTAssertTrue(overlay.showCalled, "应显示降级浮层")
    }

    // MARK: - TC-F1.9-10-02 粘贴后面板自动关闭（无权限路径）

    func testHandlePaste_NoPermission_ClosesPanelBeforeShowingOverlay()
    {
        let permissionChecker = MockPermissionChecker(granted: false)
        let writer = MockClipboardWriter()
        let panel = MockPanelCloser()
        let overlay = MockOverlayShower()
        let coordinator = PasteCoordinator(
            permissionChecker: permissionChecker,
            clipboardWriter: writer,
            panelCloser: panel,
            overlayShower: overlay
        )

        let clip = ClipItem.makeText("文本", contentType: .other, sourceApp: "com.test", sourceAppName: "Test")
        coordinator.handlePaste(clip: clip)

        // 验证关闭顺序：先关闭面板，再显示浮层
        XCTAssertTrue(panel.closeCalled, "面板应已关闭")
        XCTAssertTrue(overlay.showCalled, "浮层应已显示")
        // closeCalled 在 showCalled 之前设置（通过 callOrder 验证）
        XCTAssertLessThan(panel.callOrder, overlay.callOrder, "应先关闭面板再显示浮层")
    }

    // MARK: - TC-F1.9-12-01 权限被撤销时自动降级（降级逻辑不缓存权限状态）

    func testHandlePaste_PermissionRevoked_SwitchesToDegradedPath()
    {
        let permissionChecker = MockPermissionChecker(granted: true)
        let writer = MockClipboardWriter()
        let panel = MockPanelCloser()
        let overlay = MockOverlayShower()
        let coordinator = PasteCoordinator(
            permissionChecker: permissionChecker,
            clipboardWriter: writer,
            panelCloser: panel,
            overlayShower: overlay
        )

        let clip = ClipItem.makeText("文本", contentType: .other, sourceApp: "com.test", sourceAppName: "Test")

        // 第一次：有权限（主 Scheme 沙盒内无法模拟 Cmd+V，有权限路径回退显示降级浮层作为合规回退，与 Phase 4 Fix 10 行为一致）
        coordinator.handlePaste(clip: clip)
        XCTAssertTrue(writer.writeCalled, "有权限时应写入剪贴板")
        XCTAssertTrue(panel.closeCalled, "有权限时应关闭面板")
        XCTAssertTrue(overlay.showCalled, "有权限时主 Scheme 应显示浮层作为合规回退（Fix 10）")

        // 重置 mock
        writer.reset()
        panel.reset()
        overlay.reset()

        // 第二次：权限被撤销（模拟用户在系统设置撤销权限）
        permissionChecker.granted = false
        coordinator.handlePaste(clip: clip)

        XCTAssertTrue(writer.writeCalled, "权限撤销后仍应写入剪贴板")
        XCTAssertTrue(panel.closeCalled, "权限撤销后应关闭面板")
        XCTAssertTrue(overlay.showCalled, "权限撤销后应走降级路径显示浮层")
    }

    // MARK: - 权限检测不缓存（每次粘贴流程都重新检测）

    func testHandlePaste_ChecksPermissionEveryTime_DoesNotCache()
    {
        let permissionChecker = MockPermissionChecker(granted: false)
        let writer = MockClipboardWriter()
        let panel = MockPanelCloser()
        let overlay = MockOverlayShower()
        let coordinator = PasteCoordinator(
            permissionChecker: permissionChecker,
            clipboardWriter: writer,
            panelCloser: panel,
            overlayShower: overlay
        )

        let clip = ClipItem.makeText("文本", contentType: .other, sourceApp: "com.test", sourceAppName: "Test")

        coordinator.handlePaste(clip: clip)
        let firstCallCount = permissionChecker.checkCallCount

        coordinator.handlePaste(clip: clip)
        let secondCallCount = permissionChecker.checkCallCount

        XCTAssertEqual(secondCallCount, firstCallCount + 1, "每次粘贴流程都应重新检测权限")
    }

    // MARK: - 图片类型不写入剪贴板不关闭面板

    func testHandlePaste_ImageType_DoesNotWriteOrClose()
    {
        let permissionChecker = MockPermissionChecker(granted: false)
        let writer = MockClipboardWriter()
        let panel = MockPanelCloser()
        let overlay = MockOverlayShower()
        let coordinator = PasteCoordinator(
            permissionChecker: permissionChecker,
            clipboardWriter: writer,
            panelCloser: panel,
            overlayShower: overlay
        )

        let imageClip = ClipItem.makeImage(
            Data([0x89, 0x50]),
            contentType: .other,
            sourceApp: "com.test",
            sourceAppName: "Test"
        )
        coordinator.handlePaste(clip: imageClip)

        XCTAssertFalse(writer.writeCalled, "图片类型不应写入剪贴板")
        XCTAssertFalse(panel.closeCalled, "图片类型不应关闭面板")
        XCTAssertFalse(overlay.showCalled, "图片类型不应显示浮层")
    }

    // MARK: - 文件路径类型不写入剪贴板不关闭面板

    func testHandlePaste_FilePathType_DoesNotWriteOrClose()
    {
        let permissionChecker = MockPermissionChecker(granted: false)
        let writer = MockClipboardWriter()
        let panel = MockPanelCloser()
        let overlay = MockOverlayShower()
        let coordinator = PasteCoordinator(
            permissionChecker: permissionChecker,
            clipboardWriter: writer,
            panelCloser: panel,
            overlayShower: overlay
        )

        let filePathClip = ClipItem.makeFilePath(
            [URL(fileURLWithPath: "/tmp/test.txt")],
            contentType: .other,
            sourceApp: "com.test",
            sourceAppName: "Test"
        )
        coordinator.handlePaste(clip: filePathClip)

        XCTAssertFalse(writer.writeCalled, "文件路径类型不应写入剪贴板")
        XCTAssertFalse(panel.closeCalled, "文件路径类型不应关闭面板")
        XCTAssertFalse(overlay.showCalled, "文件路径类型不应显示浮层")
    }

    // MARK: - 剪贴板写入失败时不显示浮层（错误处理）

    func testHandlePaste_WriteFailure_DoesNotShowOverlay()
    {
        let permissionChecker = MockPermissionChecker(granted: false)
        let writer = MockClipboardWriter()
        writer.shouldSucceed = false
        let panel = MockPanelCloser()
        let overlay = MockOverlayShower()
        let coordinator = PasteCoordinator(
            permissionChecker: permissionChecker,
            clipboardWriter: writer,
            panelCloser: panel,
            overlayShower: overlay
        )

        let clip = ClipItem.makeText("文本", contentType: .other, sourceApp: "com.test", sourceAppName: "Test")
        coordinator.handlePaste(clip: clip)

        XCTAssertTrue(writer.writeCalled, "应尝试写入剪贴板")
        XCTAssertFalse(panel.closeCalled, "写入失败时不应关闭面板")
        XCTAssertFalse(overlay.showCalled, "写入失败时不应显示浮层")
    }

    // MARK: - 集成测试：QuickPastePanelController 遵循 PanelClosing

    func testQuickPastePanelController_ConformsToPanelClosing()
    {
        let locator = ScreenCenterLocatorForIntegration()
        let controller = QuickPastePanelController(screenLocator: locator)
        XCTAssertTrue(controller is PanelClosing, "QuickPastePanelController 应遵循 PanelClosing 协议")
        _ = controller
    }
}

// MARK: - Phase 4：有权限路径测试（仅 ClipMind-Dev Scheme 编译）

#if CLIPMIND_DEV

extension PasteCoordinatorTests
{
    // MARK: - TC-F1.9-6-01 有权限时双击自动粘贴（剪贴板写入 + 面板关闭 + 模拟粘贴）

    func testHandlePaste_WithPermission_WritesClipboard_ClosesPanel_SimulatesPaste()
    {
        let permissionChecker = MockPermissionChecker(granted: true)
        let writer = MockClipboardWriter()
        let panel = MockPanelCloser()
        let overlay = MockOverlayShower()
        let simulator = MockPasteSimulator()
        let coordinator = PasteCoordinator(
            permissionChecker: permissionChecker,
            clipboardWriter: writer,
            panelCloser: panel,
            overlayShower: overlay,
            pasteSimulator: simulator
        )

        let clip = ClipItem.makeText("文本", contentType: .other, sourceApp: "com.test", sourceAppName: "Test")
        coordinator.handlePaste(clip: clip)

        XCTAssertTrue(writer.writeCalled, "有权限时应写入剪贴板")
        XCTAssertEqual(writer.writtenText, "文本")
        XCTAssertTrue(panel.closeCalled, "有权限时应关闭面板")
        XCTAssertTrue(simulator.simulateCalled, "有权限时应模拟粘贴按键")
        XCTAssertFalse(overlay.showCalled, "有权限时不应显示降级浮层")
    }

    // MARK: - TC-F1.9-10-01 粘贴后面板自动关闭（有权限路径）

    func testHandlePaste_WithPermission_ClosesPanelBeforeSimulatingPaste()
    {
        let permissionChecker = MockPermissionChecker(granted: true)
        let writer = MockClipboardWriter()
        let panel = MockPanelCloser()
        let overlay = MockOverlayShower()
        let simulator = MockPasteSimulator()
        let coordinator = PasteCoordinator(
            permissionChecker: permissionChecker,
            clipboardWriter: writer,
            panelCloser: panel,
            overlayShower: overlay,
            pasteSimulator: simulator
        )

        let clip = ClipItem.makeText("文本", contentType: .other, sourceApp: "com.test", sourceAppName: "Test")
        coordinator.handlePaste(clip: clip)

        // 验证关闭顺序：先关闭面板，再模拟粘贴（设计文档第 7.4 节）
        XCTAssertTrue(panel.closeCalled)
        XCTAssertTrue(simulator.simulateCalled)
        XCTAssertLessThan(panel.callOrder, simulator.callOrder, "应先关闭面板再模拟粘贴")
    }

    // MARK: - TC-F1.9-12-01 权限被撤销时自动降级（有权限→无权限切换）

    func testHandlePaste_PermissionRevoked_SwitchesFromSimulateToOverlay()
    {
        let permissionChecker = MockPermissionChecker(granted: true)
        let writer = MockClipboardWriter()
        let panel = MockPanelCloser()
        let overlay = MockOverlayShower()
        let simulator = MockPasteSimulator()
        let coordinator = PasteCoordinator(
            permissionChecker: permissionChecker,
            clipboardWriter: writer,
            panelCloser: panel,
            overlayShower: overlay,
            pasteSimulator: simulator
        )

        let clip = ClipItem.makeText("文本", contentType: .other, sourceApp: "com.test", sourceAppName: "Test")

        // 第一次：有权限（模拟粘贴）
        coordinator.handlePaste(clip: clip)
        XCTAssertTrue(simulator.simulateCalled, "有权限时应模拟粘贴")
        XCTAssertFalse(overlay.showCalled, "有权限时不应显示浮层")

        // 重置 mock
        simulator.reset()
        overlay.reset()
        writer.reset()
        panel.reset()

        // 第二次：权限被撤销（显示浮层）
        permissionChecker.granted = false
        coordinator.handlePaste(clip: clip)

        XCTAssertFalse(simulator.simulateCalled, "权限撤销后不应模拟粘贴")
        XCTAssertTrue(overlay.showCalled, "权限撤销后应显示降级浮层")
    }

    // MARK: - 有权限但无 pasteSimulator 时回退到显示浮层（主 Scheme 行为模拟）

    func testHandlePaste_WithPermission_NoSimulator_FallsBackToOverlay()
    {
        let permissionChecker = MockPermissionChecker(granted: true)
        let writer = MockClipboardWriter()
        let panel = MockPanelCloser()
        let overlay = MockOverlayShower()
        // 不传入 pasteSimulator（模拟主 Scheme 编译时无 PasteSimulator 的情况）
        let coordinator = PasteCoordinator(
            permissionChecker: permissionChecker,
            clipboardWriter: writer,
            panelCloser: panel,
            overlayShower: overlay,
            pasteSimulator: nil
        )

        let clip = ClipItem.makeText("文本", contentType: .other, sourceApp: "com.test", sourceAppName: "Test")
        coordinator.handlePaste(clip: clip)

        XCTAssertTrue(writer.writeCalled, "应写入剪贴板")
        XCTAssertTrue(panel.closeCalled, "应关闭面板")
        XCTAssertTrue(overlay.showCalled, "无 pasteSimulator 时有权限路径应回退到显示浮层")
    }

    // MARK: - TC-F1.9-12-01 权限检测不缓存（有权限路径每次重新检测）

    func testHandlePaste_WithPermission_ChecksPermissionEveryTime()
    {
        let permissionChecker = MockPermissionChecker(granted: true)
        let writer = MockClipboardWriter()
        let panel = MockPanelCloser()
        let overlay = MockOverlayShower()
        let simulator = MockPasteSimulator()
        let coordinator = PasteCoordinator(
            permissionChecker: permissionChecker,
            clipboardWriter: writer,
            panelCloser: panel,
            overlayShower: overlay,
            pasteSimulator: simulator
        )

        let clip = ClipItem.makeText("文本", contentType: .other, sourceApp: "com.test", sourceAppName: "Test")

        coordinator.handlePaste(clip: clip)
        let firstCount = permissionChecker.checkCallCount

        coordinator.handlePaste(clip: clip)
        let secondCount = permissionChecker.checkCallCount

        XCTAssertEqual(secondCount, firstCount + 1, "每次粘贴流程都应重新检测权限")
    }
}

#endif

// MARK: - 测试辅助 Mock

private final class MockPermissionChecker: PastePermissionChecking
{
    var granted: Bool
    private(set) var checkCallCount = 0

    init(granted: Bool)
    {
        self.granted = granted
    }

    func isAccessibilityGranted() -> Bool
    {
        checkCallCount += 1
        return granted
    }
}

private final class MockClipboardWriter: ClipboardWriting
{
    var shouldSucceed = true
    private(set) var writeCalled = false
    private(set) var writtenText: String = ""

    func write(text: String) -> Bool
    {
        writeCalled = true
        writtenText = text
        return shouldSucceed
    }

    func reset()
    {
        writeCalled = false
        writtenText = ""
        shouldSucceed = true
    }
}

private final class MockPanelCloser: PanelClosing
{
    private(set) var closeCalled = false
    private(set) var callOrder = 0

    var isPanelVisible: Bool { !closeCalled }

    func closePanel()
    {
        closeCalled = true
        sharedCallSequence += 1
        callOrder = sharedCallSequence
    }

    func reset()
    {
        closeCalled = false
        callOrder = 0
    }
}

private final class MockOverlayShower: OverlayShowing
{
    private(set) var showCalled = false
    private(set) var callOrder = 0

    func showOverlay()
    {
        showCalled = true
        sharedCallSequence += 1
        callOrder = sharedCallSequence
    }

    func hideOverlay() {}

    func reset()
    {
        showCalled = false
        callOrder = 0
    }
}

@MainActor
private final class ScreenCenterLocatorForIntegration: PanelScreenLocating
{
    func locatePosition(lastClosedPosition: NSPoint?) -> NSPoint
    {
        let screenFrame = NSScreen.main?.frame ?? .zero
        return NSPoint(
            x: screenFrame.midX - QuickPastePanelController.panelSize.width / 2.0,
            y: screenFrame.midY - QuickPastePanelController.panelSize.height / 2.0
        )
    }
}

#if CLIPMIND_DEV

private final class MockPasteSimulator: PasteSimulating
{
    private(set) var simulateCalled = false
    private(set) var callOrder = 0

    func simulatePaste()
    {
        simulateCalled = true
        sharedCallSequence += 1
        callOrder = sharedCallSequence
    }

    func reset()
    {
        simulateCalled = false
        callOrder = 0
    }
}

#endif
