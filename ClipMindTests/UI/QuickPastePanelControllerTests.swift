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
}
