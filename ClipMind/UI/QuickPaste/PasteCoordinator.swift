import Foundation

/// 粘贴流程权限检测协议（依赖注入，便于测试 mock）。
///
/// Phase 3 提供默认实现 `SystemPastePermissionChecker` 复用 `PermissionRequester.axTrustedCheck(false)`。
/// Phase 4 的 `AccessibilityService` 会遵循此协议并提供 caret 定位能力。
protocol PastePermissionChecking: AnyObject
{
    /// 运行时查询辅助功能权限状态（不弹 TCC 提示）。
    /// - Returns: 当前是否已授权
    func isAccessibilityGranted() -> Bool
}

/// 系统权限检测器（默认实现，复用 PermissionRequester，prompt: false 不弹 TCC）。
///
/// 设计文档第 7.2 节：每次粘贴流程重新检测，不缓存。
/// 需求文档第 11.2 节：禁止弹 TCC 提示对话框。
final class SystemPastePermissionChecker: PastePermissionChecking
{
    func isAccessibilityGranted() -> Bool
    {
        PermissionRequester.axTrustedCheck(false)
    }
}

/// 面板关闭协议（抽象 QuickPastePanelController 便于测试 mock）。
///
/// 标记为 @MainActor 与实现类 QuickPastePanelController 保持一致，
/// 避免 Swift 5 模式下协议方法 actor 隔离不一致导致的运行时调度问题。
@MainActor
protocol PanelClosing: AnyObject
{
    /// 关闭快速粘贴面板。
    func closePanel()

    /// 面板当前是否可见。
    var isPanelVisible: Bool { get }
}

/// 粘贴流程协调器。
///
/// 设计文档第 3.3 节 + 第 4.2/4.3/4.4 节序列图。
/// 职责：接收双击/回车事件 → 检测权限 → 写剪贴板 → 关闭面板 → 分支有权限/无权限路径。
///
/// Phase 3 实现无权限降级分支（显示浮层）。
/// Phase 4 扩展有权限分支（模拟粘贴按键），通过 `pasteSimulator` 依赖实现。
///
/// 编译条件说明：
/// - 主 Scheme `ClipMind`（无 CLIPMIND_DEV）：`pasteSimulator` 参数类型为 `Any?`（默认 nil），
///   不调用模拟粘贴，有权限路径回退到显示浮层
/// - ClipMind-Dev Scheme（有 CLIPMIND_DEV）：`pasteSimulator` 传入 `PasteSimulating?`，
///   有权限路径通过 `as? PasteSimulating` 类型转换后调用模拟粘贴
///
/// 关键约束：
/// - 每次粘贴流程重新检测权限，不缓存（AC-F1.9-12）
/// - 图片/文件路径类型不写入剪贴板、不关闭面板（FR-012）
/// - 写入失败时不关闭面板、不显示浮层（错误处理）
/// - 日志不输出剪贴板原文（NFR-003）
@MainActor
final class PasteCoordinator
{
    private let permissionChecker: PastePermissionChecking
    private let clipboardWriter: ClipboardWriting
    private let panelCloser: PanelClosing
    private let overlayShower: OverlayShowing

    /// 模拟粘贴按键依赖。主 Scheme 下为 nil（不模拟粘贴，回退到显示浮层）；
    /// ClipMind-Dev Scheme 下传入 `PasteSimulating?`（通过 `#if CLIPMIND_DEV` 内的 `as? PasteSimulating` 类型转换访问）。
    /// 使用 `Any?` 避免条件编译包裹 init 参数导致的脆弱语法。
    private let pasteSimulator: Any?

    init(
        permissionChecker: PastePermissionChecking,
        clipboardWriter: ClipboardWriting,
        panelCloser: PanelClosing,
        overlayShower: OverlayShowing,
        pasteSimulator: Any? = nil
    )
    {
        self.permissionChecker = permissionChecker
        self.clipboardWriter = clipboardWriter
        self.panelCloser = panelCloser
        self.overlayShower = overlayShower
        self.pasteSimulator = pasteSimulator
    }

    /// 处理粘贴请求（由 QuickPasteViewModel.onPasteTriggered 调用）。
    /// - Parameter clip: 用户双击/回车选中的剪贴项
    func handlePaste(clip: ClipItem)
    {
        // 图片/文件路径类型不进入粘贴流程
        guard case .text(let text) = clip.content
        else {
            LogCategory.ui.info("Paste skipped: non-text content type")
            return
        }

        // 运行时检测权限（不缓存）
        let hasPermission = permissionChecker.isAccessibilityGranted()
        LogCategory.app.info("Paste flow started, permission granted: \(hasPermission)")

        // 写入剪贴板（仅文本）
        let writeSuccess = clipboardWriter.write(text: text)
        guard writeSuccess else {
            LogCategory.app.error("Clipboard write failed, abort paste flow")
            return
        }

        // 关闭快速粘贴面板
        panelCloser.closePanel()

        if hasPermission
        {
            #if CLIPMIND_DEV
            if let simulator = pasteSimulator as? PasteSimulating
            {
                // 有权限路径：模拟粘贴按键（设计文档第 7.4 节，面板关闭后再模拟粘贴）
                simulator.simulatePaste()
                LogCategory.app.info("Paste flow: permission granted path, paste simulated")
                return
            }
            #endif
            // 主 Scheme 或无 pasteSimulator 时：有权限路径回退到显示浮层（合规回退）
            overlayShower.showOverlay()
            LogCategory.app.info("Paste flow: permission granted path (compliance fallback, overlay shown)")
        } else {
            // 无权限降级路径：显示浮层
            overlayShower.showOverlay()
            LogCategory.app.info("Paste flow: degraded path, overlay shown")
        }
    }
}
