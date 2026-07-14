import XCTest

@testable import ClipMind

/// 主窗口布局尺寸测试（F1.12 bug 修复）。
///
/// 验证导航栏宽度从 700 调整为 350，并确保窗口缩小时侧边栏不会挤压详情面板导致内容溢出。
final class MainWindowLayoutTests: XCTestCase {
    /// 侧边栏最小宽度必须为 350（原值 700 过宽）
    func testSidebarMinWidthIs350() {
        XCTAssertEqual(
            LayoutConstants.sidebarMinWidth,
            350,
            "侧边栏最小宽度应为 350；当前值 \(LayoutConstants.sidebarMinWidth) 过宽会导致窗口缩小时内容溢出"
        )
    }

    /// 侧边栏最小宽度不得超过窗口最小宽度的 50%，
    /// 否则窗口缩到最小时侧边栏占据过多空间，详情面板被挤压。
    func testSidebarMinWidthDoesNotExceedHalfOfWindow() {
        let halfWindow = LayoutConstants.mainWindowMinWidth / 2
        XCTAssertLessThanOrEqual(
            LayoutConstants.sidebarMinWidth,
            halfWindow,
            "侧边栏最小宽度(\(LayoutConstants.sidebarMinWidth))不得超过窗口最小宽度的 50%(\(halfWindow))，否则详情面板空间不足"
        )
    }

    /// 窗口缩到最小时，详情面板剩余空间必须为正
    func testDetailPanelHasPositiveSpaceAtWindowMinimum() {
        let remainingSpace = LayoutConstants.mainWindowMinWidth - LayoutConstants.sidebarMinWidth
        XCTAssertGreaterThan(
            remainingSpace,
            0,
            "窗口最小宽度(\(LayoutConstants.mainWindowMinWidth))减去侧边栏最小宽度(\(LayoutConstants.sidebarMinWidth))后剩余空间必须为正"
        )
    }

    /// 窗口最小尺寸常量必须保持稳定（回归保护）
    func testMainWindowMinimumDimensions() {
        XCTAssertEqual(LayoutConstants.mainWindowMinWidth, 980, "窗口最小宽度应为 980")
        XCTAssertEqual(LayoutConstants.mainWindowMinHeight, 500, "窗口最小高度应为 500")
    }

    /// F1.14: App 级外层 frame minWidth 不得小于 MainWindow 内层 minWidth。
    ///
    /// ClipMindApp 用外层 frame 包裹 MainWindow，若外层 minWidth < 内层 minWidth，
    /// 窗口被外层限制到小于内层期望的宽度，NavigationView 布局冲突，
    /// 缩窗时侧边栏内容（搜索栏 + 列表）被推出窗口可见区域。
    func testAppWindowMinWidthNotSmallerThanMainWindowMinWidth() {
        XCTAssertGreaterThanOrEqual(
            LayoutConstants.appWindowMinWidth,
            LayoutConstants.mainWindowMinWidth,
            "appWindowMinWidth(\(LayoutConstants.appWindowMinWidth)) 不得小于 "
            + "mainWindowMinWidth(\(LayoutConstants.mainWindowMinWidth)), 缩窗侧边栏溢出"
        )
    }

    /// F1.14: App 级外层 frame minHeight 不得小于 MainWindow 内层 minHeight。
    func testAppWindowMinHeightNotSmallerThanMainWindowMinHeight() {
        XCTAssertGreaterThanOrEqual(
            LayoutConstants.appWindowMinHeight,
            LayoutConstants.mainWindowMinHeight,
            "appWindowMinHeight(\(LayoutConstants.appWindowMinHeight)) 不得小于 "
            + "mainWindowMinHeight(\(LayoutConstants.mainWindowMinHeight))"
        )
    }
}
