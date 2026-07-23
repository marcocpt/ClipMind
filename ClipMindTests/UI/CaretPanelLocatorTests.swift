import AppKit
import Foundation
import XCTest

@testable import ClipMind

#if CLIPMIND_DEV

/// caret 附近面板定位器测试（Phase 4，仅 ClipMind-Dev Scheme 编译）。
///
/// 覆盖 caret 定位优先级：有 caret → caret 附近；无 caret → 鼠标位置；
/// 无权限 → 上次关闭位置；无权限无上次位置 → 屏幕中央。
final class CaretPanelLocatorTests: XCTestCase
{
    /// 测试用固定屏幕尺寸，避免依赖宿主机实际分辨率造成非确定性失败。
    private let testScreenFrame = NSRect(x: 0, y: 0, width: 1512, height: 944)

    // MARK: - 有 caret 时面板定位到 caret 附近（不遮挡 caret）

    func testLocatePosition_WithCaret_ReturnsPositionNearCaret()
    {
        let caret = NSPoint(x: 500, y: 400)
        let mouse = NSPoint(x: 100, y: 100)
        let locator = CaretPanelLocator(
            accessibilityService: MockAccessibilityService(caret: caret, mouse: mouse, granted: true),
            screenFrameProvider: { self.testScreenFrame }
        )

        let position = locator.locatePosition(lastClosedPosition: nil)
        let panelSize = QuickPastePanelController.panelSize

        // 面板应在 caret 附近（含偏移量与面板尺寸的容差）
        let distanceX = abs(position.x - caret.x)
        let distanceY = abs(position.y - caret.y)
        XCTAssertLessThanOrEqual(distanceX, 50 + panelSize.width, "面板 X 坐标应在 caret 附近")
        XCTAssertLessThanOrEqual(distanceY, 50 + panelSize.height, "面板 Y 坐标应在 caret 附近")
    }

    // MARK: - 无 caret 时降级到鼠标位置

    func testLocatePosition_NoCaret_FallsBackToMouseLocation()
    {
        let mouse = NSPoint(x: 700, y: 800)
        let locator = CaretPanelLocator(
            accessibilityService: MockAccessibilityService(caret: nil, mouse: mouse, granted: true),
            screenFrameProvider: { self.testScreenFrame }
        )

        let position = locator.locatePosition(lastClosedPosition: nil)
        let panelSize = QuickPastePanelController.panelSize

        let distanceX = abs(position.x - mouse.x)
        let distanceY = abs(position.y - mouse.y)
        XCTAssertLessThanOrEqual(distanceX, panelSize.width, "无 caret 时面板应在鼠标位置附近")
        XCTAssertLessThanOrEqual(distanceY, panelSize.height, "无 caret 时面板应在鼠标位置附近")
    }

    // MARK: - 无权限时降级到上次关闭位置

    func testLocatePosition_NoPermission_UsesLastClosedPosition()
    {
        let lastClosed = NSPoint(x: 200, y: 300)
        let locator = CaretPanelLocator(
            accessibilityService: MockAccessibilityService(
                caret: nil,
                mouse: NSPoint(x: 999, y: 999),
                granted: false
            ),
            screenFrameProvider: { self.testScreenFrame }
        )

        let position = locator.locatePosition(lastClosedPosition: lastClosed)

        XCTAssertEqual(position.x, lastClosed.x, accuracy: 0.01, "无权限时应使用上次关闭位置")
        XCTAssertEqual(position.y, lastClosed.y, accuracy: 0.01, "无权限时应使用上次关闭位置")
    }

    // MARK: - 无权限且无上次关闭位置时降级到屏幕中央

    func testLocatePosition_NoPermission_NoLastClosed_UsesScreenCenter()
    {
        let locator = CaretPanelLocator(
            accessibilityService: MockAccessibilityService(
                caret: nil,
                mouse: NSPoint(x: 999, y: 999),
                granted: false
            ),
            screenFrameProvider: { self.testScreenFrame }
        )

        let position = locator.locatePosition(lastClosedPosition: nil)
        let panelSize = QuickPastePanelController.panelSize

        let expectedX = testScreenFrame.midX - panelSize.width / 2.0
        let expectedY = testScreenFrame.midY - panelSize.height / 2.0
        XCTAssertEqual(position.x, expectedX, accuracy: 1.0, "无权限无上次位置时应使用屏幕中央")
        XCTAssertEqual(position.y, expectedY, accuracy: 1.0, "无权限无上次位置时应使用屏幕中央")
    }

    // MARK: - 面板不遮挡 caret（面板位于 caret 右侧或下方）

    func testLocatePosition_PanelDoesNotOverlapCaret()
    {
        let caret = NSPoint(x: 500, y: 400)
        let locator = CaretPanelLocator(
            accessibilityService: MockAccessibilityService(
                caret: caret,
                mouse: NSPoint(x: 100, y: 100),
                granted: true
            ),
            screenFrameProvider: { self.testScreenFrame }
        )

        let position = locator.locatePosition(lastClosedPosition: nil)
        let panelSize = QuickPastePanelController.panelSize
        let panelRect = NSRect(origin: position, size: panelSize)

        XCTAssertFalse(panelRect.contains(caret), "面板不应遮挡 caret")
    }

    // MARK: - 测试辅助 Mock

    private final class MockAccessibilityService: PastePermissionChecking, CaretLocating, MousePositionProviding
    {
        let caret: NSPoint?
        let mouse: NSPoint
        let granted: Bool

        init(caret: NSPoint?, mouse: NSPoint, granted: Bool)
        {
            self.caret = caret
            self.mouse = mouse
            self.granted = granted
        }

        func isAccessibilityGranted() -> Bool { granted }
        func locateCaret() -> NSPoint? { caret }
        func currentMouseLocation() -> NSPoint { mouse }
    }
}

#endif
