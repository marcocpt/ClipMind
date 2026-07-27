import AppKit
import Foundation

#if CLIPMIND_DEV

/// caret 附近面板定位器（合规待定，仅 ClipMind-Dev Scheme 编译）。
///
/// 设计文档第 3.1 节 + 第 4.1 节序列图 + 第 7.1 节。
/// 职责：根据权限状态与 caret 可用性计算面板显示坐标。
///
/// 定位优先级：
/// 1. 有权限 + 有 caret → caret 附近（偏移 50px，不遮挡 caret）
/// 2. 有权限 + 无 caret → 鼠标当前位置附近
/// 3. 无权限 + 有上次关闭位置 → 上次关闭位置
/// 4. 无权限 + 无上次关闭位置 → 屏幕中央
///
/// 多屏支持：面板钳制时按 caret/鼠标所在屏幕的 frame 计算，避免在外置显示器
/// 输入时面板被强制拉回主屏（F1.11 「全局快捷键弹出窗口没有跟随输入外置就近出现」）。
///
/// 遵循 PanelScreenLocating 协议（Phase 1 定义），替代 ScreenCenterPanelLocator。
final class CaretPanelLocator: PanelScreenLocating
{
    /// caret 附近的偏移量（像素），面板位于 caret 右下方，不遮挡 caret。
    private static let caretOffset: CGFloat = 50

    private let accessibilityService: PastePermissionChecking & CaretLocating & MousePositionProviding
    private let screenFrameProvider: () -> NSRect
    private let screenFinder: (NSPoint) -> NSRect

    /// - Parameters:
    ///   - accessibilityService: 辅助功能服务（提供权限检测 + caret 定位 + 鼠标位置）
    ///   - screenFrameProvider: 主屏尺寸提供器（默认读取 NSScreen.main，便于测试注入固定屏幕尺寸；
    ///     用于无权限无上次位置时的屏幕中央降级）
    ///   - screenFinder: 根据坐标查找所在屏幕 frame 的闭包（默认遍历 NSScreen.screens，
    ///     找不到时回退到主屏）。用于多屏钳制，确保面板留在 caret/鼠标所在屏幕内。
    init(
        accessibilityService: PastePermissionChecking & CaretLocating & MousePositionProviding,
        screenFrameProvider: @escaping () -> NSRect = { NSScreen.main?.frame ?? .zero },
        screenFinder: @escaping (NSPoint) -> NSRect = { point in
            NSScreen.screens.first { $0.frame.contains(point) }?.frame
                ?? NSScreen.main?.frame
                ?? .zero
        }
    )
    {
        self.accessibilityService = accessibilityService
        self.screenFrameProvider = screenFrameProvider
        self.screenFinder = screenFinder
    }

    func locatePosition(lastClosedPosition: NSPoint?) -> NSPoint
    {
        let panelSize = QuickPastePanelController.panelSize
        let mainScreenFrame = screenFrameProvider()

        // 有权限时尝试 caret 定位
        if accessibilityService.isAccessibilityGranted()
        {
            let caret = accessibilityService.locateCaret()

            // caret 坐标有效性检测：Electron 应用（如 Trae CN）对 AXUIElement 支持有限，
            // locateCaret() 可能返回 (0, 0) 这种无效坐标（而非 nil）。若直接进入 caret
            // 分支计算 (0+50, 0-50-panelHeight) = (50, -50-panelHeight)，经 clampToScreen
            // 后会被钳制到 (50, 0) 即屏幕左下角。当 caret 位于原点 (0, 0) 时视为无效，
            // 降级到鼠标位置。
            if let caretValid = caret, !isOriginPoint(caretValid)
            {
                let position = NSPoint(
                    x: caretValid.x + Self.caretOffset,
                    y: caretValid.y - Self.caretOffset - panelSize.height
                )
                // 多屏：以 caret 为锚点找到所在屏幕，再钳制到该屏可视范围
                return clampToScreen(position: position, panelSize: panelSize, anchor: caretValid)
            } else {
                let mouse = accessibilityService.currentMouseLocation()

                // 鼠标位置无效检测：CGEvent(source: nil) 在非激活面板应用中可能返回 nil，
                // NSEvent.mouseLocation 在未接收鼠标事件时返回 (0, 0)。经 clampToScreen
                // 后面板会被钳制到屏幕左下角 (0, 0)，影响 Trae CN 等 Electron 应用。
                // 当鼠标位置为原点 (0, 0) 时视为无效，降级到屏幕中央。
                if isOriginPoint(mouse)
                {
                    return NSPoint(
                        x: mainScreenFrame.midX - panelSize.width / 2.0,
                        y: mainScreenFrame.midY - panelSize.height / 2.0
                    )
                }

                let position = NSPoint(
                    x: mouse.x - panelSize.width / 2.0,
                    y: mouse.y - panelSize.height / 2.0
                )
                // 多屏：以鼠标为锚点找到所在屏幕
                return clampToScreen(position: position, panelSize: panelSize, anchor: mouse)
            }
        }

        if let lastClosed = lastClosedPosition
        {
            return lastClosed
        }

        return NSPoint(
            x: mainScreenFrame.midX - panelSize.width / 2.0,
            y: mainScreenFrame.midY - panelSize.height / 2.0
        )
    }

    // MARK: - 私有

    /// 判断坐标是否为屏幕原点 (0, 0)。
    ///
    /// 屏幕原点视为无效坐标：AXUIElement 在 Electron 应用中可能返回 (0, 0) 的 caret，
    /// CGEvent/NSEvent 在非激活面板应用中可能返回 (0, 0) 的鼠标位置。
    /// 这些值经 clampToScreen 后会把面板钳制到屏幕左下角，需要识别并降级。
    private func isOriginPoint(_ point: NSPoint) -> Bool
    {
        point.x == 0 && point.y == 0
    }

    /// 将面板位置限制在锚点所在屏幕的可视范围内（避免超出屏幕边界）。
    ///
    /// - Parameters:
    ///   - position: 面板期望左下角坐标
    ///   - panelSize: 面板尺寸
    ///   - anchor: 锚点坐标（caret 或鼠标位置），用于查找所在屏幕
    /// - Returns: 钳制后的面板左下角坐标，保持在锚点所在屏幕内
    private func clampToScreen(position: NSPoint, panelSize: NSSize, anchor: NSPoint) -> NSPoint
    {
        let screenFrame = screenFinder(anchor)
        let clampedX = max(screenFrame.minX, min(position.x, screenFrame.maxX - panelSize.width))
        let clampedY = max(screenFrame.minY, min(position.y, screenFrame.maxY - panelSize.height))
        return NSPoint(x: clampedX, y: clampedY)
    }
}

#endif
