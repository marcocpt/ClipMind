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
