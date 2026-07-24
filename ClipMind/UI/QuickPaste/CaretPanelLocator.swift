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
/// 遵循 PanelScreenLocating 协议（Phase 1 定义），替代 ScreenCenterPanelLocator。
final class CaretPanelLocator: PanelScreenLocating
{
    /// caret 附近的偏移量（像素），面板位于 caret 右下方，不遮挡 caret。
    private static let caretOffset: CGFloat = 50

    private let accessibilityService: PastePermissionChecking & CaretLocating & MousePositionProviding
    private let screenFrameProvider: () -> NSRect

    /// - Parameters:
    ///   - accessibilityService: 辅助功能服务（提供权限检测 + caret 定位 + 鼠标位置）
    ///   - screenFrameProvider: 屏幕尺寸提供器（默认读取 NSScreen.main，便于测试注入固定屏幕尺寸）
    init(
        accessibilityService: PastePermissionChecking & CaretLocating & MousePositionProviding,
        screenFrameProvider: @escaping () -> NSRect = { NSScreen.main?.frame ?? .zero }
    )
    {
        self.accessibilityService = accessibilityService
        self.screenFrameProvider = screenFrameProvider
    }

    func locatePosition(lastClosedPosition: NSPoint?) -> NSPoint
    {
        let panelSize = QuickPastePanelController.panelSize
        let screenFrame = screenFrameProvider()

        // 有权限时尝试 caret 定位
        if accessibilityService.isAccessibilityGranted()
        {
            if let caret = accessibilityService.locateCaret()
            {
                let position = NSPoint(
                    x: caret.x + Self.caretOffset,
                    y: caret.y - Self.caretOffset - panelSize.height
                )
                return clampToScreen(position: position, panelSize: panelSize, screenFrame: screenFrame)
            } else {
                let mouse = accessibilityService.currentMouseLocation()
                let position = NSPoint(
                    x: mouse.x - panelSize.width / 2.0,
                    y: mouse.y - panelSize.height / 2.0
                )
                return clampToScreen(position: position, panelSize: panelSize, screenFrame: screenFrame)
            }
        }

        if let lastClosed = lastClosedPosition
        {
            return lastClosed
        }

        return NSPoint(
            x: screenFrame.midX - panelSize.width / 2.0,
            y: screenFrame.midY - panelSize.height / 2.0
        )
    }

    // MARK: - 私有

    /// 将面板位置限制在屏幕可视范围内（避免超出屏幕边界）。
    private func clampToScreen(position: NSPoint, panelSize: NSSize, screenFrame: NSRect) -> NSPoint
    {
        let clampedX = max(screenFrame.minX, min(position.x, screenFrame.maxX - panelSize.width))
        let clampedY = max(screenFrame.minY, min(position.y, screenFrame.maxY - panelSize.height))
        return NSPoint(x: clampedX, y: clampedY)
    }
}

#endif
