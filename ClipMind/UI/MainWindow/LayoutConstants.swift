import CoreGraphics
import Foundation

/// 主窗口布局尺寸常量。
///
/// 将魔术数字提取为命名常量，便于测试验证与统一维护。
/// 对应 bug 修复 F1.12：导航栏宽度从 700 调整为 350，解决窗口缩小时内容溢出。
/// 对应 bug 修复 F1.14：消除 ClipMindApp 外层 frame 与 MainWindow 内层 frame 的嵌套冲突。
enum LayoutConstants {
    /// 侧边栏（导航栏）最小宽度。
    ///
    /// 原值 700 过宽，窗口缩到最小时侧边栏无法收缩导致搜索框和列表溢出窗口边界。
    /// 调整为 350 后侧边栏可充分收缩，留足空间给详情面板。
    static let sidebarMinWidth: CGFloat = 350

    /// 主窗口最小宽度。
    static let mainWindowMinWidth: CGFloat = 980

    /// 主窗口最小高度。
    static let mainWindowMinHeight: CGFloat = 500

    /// App 级窗口最小宽度（ClipMindApp 中包裹 MainWindow 的外层 frame）。
    ///
    /// 必须与 `mainWindowMinWidth` 一致或更大。若外层 frame minWidth 小于 MainWindow
    /// 内层 minWidth，窗口会被外层限制到小于内层期望的宽度，导致 NavigationView
    /// 布局冲突，缩窗时侧边栏内容（搜索栏 + 列表）被推出窗口可见区域（F1.14）。
    /// F1.14 由原值 900 调整为 980，与 mainWindowMinWidth 对齐消除嵌套冲突。
    static let appWindowMinWidth: CGFloat = 980

    /// App 级窗口最小高度（ClipMindApp 中包裹 MainWindow 的外层 frame）。
    ///
    /// 必须与 `mainWindowMinHeight` 一致或更大，避免嵌套 frame 高度冲突。
    /// F1.14 由原值 600 调整为 500，与 mainWindowMinHeight 对齐。
    static let appWindowMinHeight: CGFloat = 500
}
