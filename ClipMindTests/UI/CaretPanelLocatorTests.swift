import AppKit
import Foundation
import XCTest

@testable import ClipMind

#if CLIPMIND_DEV

/// caret 附近面板定位器测试（Phase 4，仅 ClipMind-Dev Scheme 编译）。
///
/// 覆盖 caret 定位优先级：有 caret → caret 附近；无 caret → 鼠标位置；
/// 无权限 → 上次关闭位置；无权限无上次位置 → 屏幕中央。
///
/// 标记 `@MainActor`：被测对象 `CaretPanelLocator` 实现 `PanelScreenLocating`（@MainActor），
/// 且 `screenFinder` 默认闭包引用 `NSScreen.screens`（main actor-isolated），需要主线程上下文。
@MainActor
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

    // MARK: - 多屏：caret 在外置显示器时面板应留在副屏

    /// 主屏在左、副屏在右。caret 坐标落在副屏内时，面板应钳制到副屏可视范围内，
    /// 而不是回退到主屏。这是 F1.11 「全局快捷键弹出窗口没有跟随输入外置就近出现」的回归测试。
    func testLocatePosition_CaretOnExternalDisplay_PanelStaysOnExternalDisplay()
    {
        let mainFrame = NSRect(x: 0, y: 0, width: 1512, height: 944)
        let externalFrame = NSRect(x: 1512, y: 0, width: 1920, height: 1080)
        let screens = [mainFrame, externalFrame]

        let caret = NSPoint(x: 2000, y: 500)
        let locator = CaretPanelLocator(
            accessibilityService: MockAccessibilityService(
                caret: caret,
                mouse: NSPoint(x: 100, y: 100),
                granted: true
            ),
            screenFrameProvider: { mainFrame },
            screenFinder: { point in
                screens.first { $0.contains(point) } ?? mainFrame
            }
        )

        let position = locator.locatePosition(lastClosedPosition: nil)
        let panelSize = QuickPastePanelController.panelSize
        let panelRect = NSRect(origin: position, size: panelSize)

        XCTAssertTrue(
            externalFrame.contains(panelRect),
            "caret 在副屏时面板应留在副屏内，实际位置：\(position)"
        )
    }

    // MARK: - 多屏：无 caret 时鼠标在外置显示器时面板应留在副屏

    func testLocatePosition_MouseOnExternalDisplay_PanelStaysOnExternalDisplay()
    {
        let mainFrame = NSRect(x: 0, y: 0, width: 1512, height: 944)
        let externalFrame = NSRect(x: 1512, y: 0, width: 1920, height: 1080)
        let screens = [mainFrame, externalFrame]

        let mouse = NSPoint(x: 2000, y: 500)
        let locator = CaretPanelLocator(
            accessibilityService: MockAccessibilityService(
                caret: nil,
                mouse: mouse,
                granted: true
            ),
            screenFrameProvider: { mainFrame },
            screenFinder: { point in
                screens.first { $0.contains(point) } ?? mainFrame
            }
        )

        let position = locator.locatePosition(lastClosedPosition: nil)
        let panelSize = QuickPastePanelController.panelSize
        let panelRect = NSRect(origin: position, size: panelSize)

        XCTAssertTrue(
            externalFrame.contains(panelRect),
            "鼠标在副屏时面板应留在副屏内，实际位置：\(position)"
        )
    }

    // MARK: - 鼠标位置无效时降级到屏幕中央（修复 Trae CN 等 Electron 应用左下角 bug）

    /// Bug 场景：在 Trae CN 等 Electron 应用中按全局热键，面板停在屏幕左下角 (0, 0)。
    ///
    /// 根因：Electron 应用不支持 AXSelectedTextRange，locateCaret() 返回 nil；
    /// 降级到 currentMouseLocation() 时，CGEvent(source: nil) 在非激活面板应用中
    /// 可能返回 nil 或 .zero，NSEvent.mouseLocation 也可能返回 (0, 0)；
    /// 经 clampToScreen 后面板被钳制到屏幕左下角 (0, 0)。
    ///
    /// 期望：鼠标位置明显无效（位于屏幕原点）时，应降级到屏幕中央，
    /// 而不是停在左下角。
    func testLocatePosition_NoCaret_InvalidMouseLocation_FallsBackToScreenCenter()
    {
        // 模拟 Trae CN 场景：caret 不可用，鼠标位置返回 (0, 0)
        let mouse = NSPoint(x: 0, y: 0)
        let locator = CaretPanelLocator(
            accessibilityService: MockAccessibilityService(
                caret: nil,
                mouse: mouse,
                granted: true
            ),
            screenFrameProvider: { self.testScreenFrame }
        )

        let position = locator.locatePosition(lastClosedPosition: nil)
        let panelSize = QuickPastePanelController.panelSize

        // 不应停在左下角 (0, 0)
        XCTAssertFalse(
            position.x == 0 && position.y == 0,
            "鼠标位置无效时不应停在屏幕左下角，实际位置：\(position)"
        )

        // 应降级到屏幕中央
        let expectedX = testScreenFrame.midX - panelSize.width / 2.0
        let expectedY = testScreenFrame.midY - panelSize.height / 2.0
        XCTAssertEqual(position.x, expectedX, accuracy: 1.0, "鼠标位置无效时应降级到屏幕中央")
        XCTAssertEqual(position.y, expectedY, accuracy: 1.0, "鼠标位置无效时应降级到屏幕中央")
    }

    // MARK: - caret 坐标无效（位于屏幕原点）时降级到鼠标位置（修复 Trae CN 等 Electron 应用左下角 bug）

    /// Bug 场景：在 Trae CN 等 Electron 应用中按全局热键，面板停在屏幕左下角。
    ///
    /// 真实根因：Electron 应用对 AXUIElement 支持有限，locateCaret() 可能返回
    /// (0, 0) 这种无效坐标（而非 nil）。代码进入 caret 分支计算
    /// position = (0+50, 0-50-panelHeight) = (50, -50-panelHeight)，
    /// 经 clampToScreen(anchor: (0,0)) 后被钳制到 (50, 0)，即屏幕左下角。
    ///
    /// 期望：caret 坐标明显无效（位于屏幕原点）时，应降级到鼠标位置；
    /// 若鼠标位置也无效，再降级到屏幕中央。不应停在左下角。
    func testLocatePosition_InvalidCaretAtOrigin_FallsBackToMouseLocation()
    {
        // 模拟 Trae CN 场景：caret 返回 (0, 0) 无效坐标，鼠标位置有效
        let caret = NSPoint(x: 0, y: 0)
        let mouse = NSPoint(x: 700, y: 800)
        let locator = CaretPanelLocator(
            accessibilityService: MockAccessibilityService(
                caret: caret,
                mouse: mouse,
                granted: true
            ),
            screenFrameProvider: { self.testScreenFrame }
        )

        let position = locator.locatePosition(lastClosedPosition: nil)
        let panelSize = QuickPastePanelController.panelSize

        // 不应停在左下角附近
        XCTAssertFalse(
            position.x <= 50 && position.y == 0,
            "caret 无效时不应停在屏幕左下角，实际位置：\(position)"
        )

        // 应降级到鼠标位置附近
        let distanceX = abs(position.x - mouse.x)
        let distanceY = abs(position.y - mouse.y)
        XCTAssertLessThanOrEqual(distanceX, panelSize.width, "caret 无效时应降级到鼠标位置附近")
        XCTAssertLessThanOrEqual(distanceY, panelSize.height, "caret 无效时应降级到鼠标位置附近")
    }

    // MARK: - caret 与鼠标位置都无效时降级到屏幕中央

    /// Bug 场景：Trae CN 中 caret 返回 (0,0)，鼠标位置也返回 (0,0)。
    ///
    /// 期望：双重无效时降级到屏幕中央，绝不停在左下角。
    func testLocatePosition_InvalidCaretAndInvalidMouse_FallsBackToScreenCenter()
    {
        let caret = NSPoint(x: 0, y: 0)
        let mouse = NSPoint(x: 0, y: 0)
        let locator = CaretPanelLocator(
            accessibilityService: MockAccessibilityService(
                caret: caret,
                mouse: mouse,
                granted: true
            ),
            screenFrameProvider: { self.testScreenFrame }
        )

        let position = locator.locatePosition(lastClosedPosition: nil)
        let panelSize = QuickPastePanelController.panelSize

        // 不应停在左下角附近
        XCTAssertFalse(
            position.x <= 50 && position.y == 0,
            "caret 与鼠标都无效时不应停在屏幕左下角，实际位置：\(position)"
        )

        // 应降级到屏幕中央
        let expectedX = testScreenFrame.midX - panelSize.width / 2.0
        let expectedY = testScreenFrame.midY - panelSize.height / 2.0
        XCTAssertEqual(position.x, expectedX, accuracy: 1.0, "双重无效时应降级到屏幕中央")
        XCTAssertEqual(position.y, expectedY, accuracy: 1.0, "双重无效时应降级到屏幕中央")
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
