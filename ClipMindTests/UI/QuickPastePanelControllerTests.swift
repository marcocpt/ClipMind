import AppKit
@testable import ClipMind
import XCTest

final class QuickPastePanelControllerTests: XCTestCase
{
    // MARK: - TC-F1.9-3-01 无权限时面板显示在屏幕中央

    func testShowPanel_AtScreenCenter_WhenNoLastPosition()
    {
        let controller = QuickPastePanelController(
            screenLocator: ScreenCenterLocator()
        )
        controller.showPanel()

        XCTAssertTrue(controller.isPanelVisible, "面板应已显示")
        let panelFrame = controller.panelFrameForTesting
        let screenFrame = NSScreen.main?.frame ?? .zero
        let expectedCenterX = screenFrame.midX - panelFrame.width / 2.0
        let expectedCenterY = screenFrame.midY - panelFrame.height / 2.0
        XCTAssertEqual(
            panelFrame.midX,
            expectedCenterX + panelFrame.width / 2.0,
            accuracy: 1.0,
            "面板应在屏幕水平中央"
        )
        XCTAssertEqual(
            panelFrame.midY,
            expectedCenterY + panelFrame.height / 2.0,
            accuracy: 1.0,
            "面板应在屏幕垂直中央"
        )

        controller.closePanel()
    }

    // MARK: - 状态机单一性（TC-F1.9-S-02 子项：重复关闭不崩溃）

    func testClosePanel_WhenAlreadyClosed_DoesNotCrash()
    {
        let controller = QuickPastePanelController(
            screenLocator: ScreenCenterLocator()
        )
        controller.closePanel()
        controller.closePanel()
        XCTAssertFalse(controller.isPanelVisible, "重复关闭后仍应为不可见状态")
    }

    // MARK: - 测试辅助：屏幕中央定位器

    /// 屏幕中央定位器（模拟无权限路径的定位逻辑）。
    private final class ScreenCenterLocator: PanelScreenLocating
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

    // MARK: - TC-F1.9-3-02 无权限时面板显示在上次关闭位置

    func testShowPanel_AtLastClosedPosition_WhenPositionInVisibleRange()
    {
        let locator = LastClosedPositionLocator()
        let controller = QuickPastePanelController(screenLocator: locator)

        // 使用 visibleFrame（排除菜单栏和 Dock）计算位置，确保面板完全在可视范围内，
        // 避免 macOS 在 makeKeyAndOrderFront 时自动调整位置导致断言失败。
        let visibleFrame = NSScreen.main?.visibleFrame ?? NSScreen.main?.frame ?? .zero
        let panelSize = QuickPastePanelController.panelSize
        // 偏移 20 点（确保仍在 visibleFrame 内，不被 macOS 约束调整）
        let recordedPosition = NSPoint(
            x: visibleFrame.minX + (visibleFrame.width - panelSize.width) / 2.0 + 20,
            y: visibleFrame.minY + (visibleFrame.height - panelSize.height) / 2.0 + 20
        )
        controller.setLastClosedPositionForTesting(recordedPosition)

        controller.showPanel()

        let panelFrame = controller.panelFrameForTesting
        XCTAssertEqual(panelFrame.origin.x, recordedPosition.x, accuracy: 1.0, "面板应在上次关闭位置")
        XCTAssertEqual(panelFrame.origin.y, recordedPosition.y, accuracy: 1.0, "面板应在上次关闭位置")

        controller.closePanel()
    }

    // MARK: - 屏幕可视范围校验（上次位置超出屏幕时降级到屏幕中央）

    func testShowPanel_FallsBackToScreenCenter_WhenLastPositionOutOfScreen()
    {
        let locator = LastClosedPositionLocator()
        let controller = QuickPastePanelController(screenLocator: locator)

        // 模拟上次关闭位置在屏幕外（负坐标）
        controller.setLastClosedPositionForTesting(NSPoint(x: -10000, y: -10000))

        controller.showPanel()

        let panelFrame = controller.panelFrameForTesting
        let screenFrame = NSScreen.main?.frame ?? .zero
        let expectedCenterX = screenFrame.midX - panelFrame.width / 2.0
        XCTAssertEqual(panelFrame.origin.x, expectedCenterX, accuracy: 1.0, "上次位置超出屏幕时应降级到屏幕中央")

        controller.closePanel()
    }

    // MARK: - 测试辅助：上次关闭位置定位器

    /// 上次关闭位置定位器（无权限路径使用 lastClosedPosition）。
    private final class LastClosedPositionLocator: PanelScreenLocating
    {
        func locatePosition(lastClosedPosition: NSPoint?) -> NSPoint
        {
            guard let lastClosedPosition = lastClosedPosition,
                  isPositionVisible(lastClosedPosition)
            else
            {
                let screenFrame = NSScreen.main?.frame ?? .zero
                return NSPoint(
                    x: screenFrame.midX - QuickPastePanelController.panelSize.width / 2.0,
                    y: screenFrame.midY - QuickPastePanelController.panelSize.height / 2.0
                )
            }
            return lastClosedPosition
        }

        private func isPositionVisible(_ position: NSPoint) -> Bool
        {
            let screenFrame = NSScreen.main?.frame ?? .zero
            let panelSize = QuickPastePanelController.panelSize
            let panelRect = NSRect(origin: position, size: panelSize)
            return screenFrame.contains(panelRect)
        }
    }

    // MARK: - TC-F1.9-8-01 Esc 键关闭面板不粘贴

    func testClosePanel_OnEscKey_ClosesPanelWithoutPaste()
    {
        let controller = QuickPastePanelController(screenLocator: ScreenCenterLocator())
        var pasteCalled = false
        controller.onPasteTriggeredForTesting = { _ in pasteCalled = true }

        controller.showPanel()
        XCTAssertTrue(controller.isPanelVisible)

        controller.handleEscKeyForTesting()

        XCTAssertFalse(controller.isPanelVisible, "Esc 键应关闭面板")
        XCTAssertFalse(pasteCalled, "Esc 关闭不应触发粘贴流程")
    }

    // MARK: - TC-F1.9-9-01 面板失焦自动关闭

    func testClosePanel_OnResignKey_ClosesPanelWithoutPaste()
    {
        let controller = QuickPastePanelController(screenLocator: ScreenCenterLocator())
        var pasteCalled = false
        controller.onPasteTriggeredForTesting = { _ in pasteCalled = true }

        controller.showPanel()
        XCTAssertTrue(controller.isPanelVisible)

        controller.handleDidResignKeyForTesting()

        XCTAssertFalse(controller.isPanelVisible, "失焦应关闭面板")
        XCTAssertFalse(pasteCalled, "失焦关闭不应触发粘贴流程")
    }

    // MARK: - TC-F1.9-S-02 三种关闭路径互不冲突（双击+失焦竞态）

    func testClosePanel_OnEscAndResignKey_OnlyClosesOnce()
    {
        let controller = QuickPastePanelController(screenLocator: ScreenCenterLocator())
        controller.showPanel()
        XCTAssertTrue(controller.isPanelVisible)

        controller.handleEscKeyForTesting()
        let visibleAfterEsc = controller.isPanelVisible
        controller.handleDidResignKeyForTesting()

        XCTAssertFalse(visibleAfterEsc, "Esc 后应已关闭")
        XCTAssertFalse(controller.isPanelVisible, "再次失焦不应崩溃或重复关闭")
    }
}
