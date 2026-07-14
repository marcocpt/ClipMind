import CoreGraphics
import Foundation

/// 主窗口布局尺寸常量。
///
/// 将魔术数字提取为命名常量，便于测试验证与统一维护。
/// 对应 bug 修复 F1.12：导航栏宽度从 700 调整为 350，解决窗口缩小时内容溢出。
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
}
