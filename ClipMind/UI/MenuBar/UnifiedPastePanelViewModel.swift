import Foundation

/// 统一粘贴面板视图状态管理器（F1.11 Phase 1）。
///
/// 由 F1.9 的 `QuickPasteViewModel` 迁移而来，承载两个场景共用的高亮选中状态、
/// 单击 / 双击 / 回车 / 方向键 / Esc 事件路由、`shouldShowTextOnlyHint` 提示状态。
///
/// 设计文档第 3.3 节、第 5.2 节。视图本身不读取剪贴板存储，剪贴项列表由外部注入。
@MainActor
final class UnifiedPastePanelViewModel: ObservableObject
{
    /// 当前高亮选中行索引（默认 0，空列表为 -1）。
    @Published var selectedIndex: Int

    /// 双击 / 回车触发的粘贴回调（由控制器注入 PasteCoordinator.handlePaste）。
    var onPasteTriggered: ((ClipItem) -> Void)?

    /// 测试用：记录最近触发 onPasteTriggered 的 clip.id，供 UI 测试通过测试元素验证回调被调用。
    /// 仅在测试启动参数下通过视图的测试元素暴露，不影响生产行为。
    @Published var lastTriggeredClipIdForTesting: String?

    /// 是否显示「仅支持文本粘贴」提示（双击图片 / 文件路径行时为 true）。
    @Published var shouldShowTextOnlyHint = false

    /// Esc 键回调（由控制器关闭面板）。
    var onEscPressed: (() -> Void)?

    /// 「退出」按钮回调（由控制器退出整个应用）。
    ///
    /// F1.11 Bug Fix：原实现将「退出」按钮定义为关闭弹窗（与 Esc 行为重复），
    /// 但用户期望「退出」按钮退出整个应用。调整为独立的 `onExitApp` 回调，
    /// 由 `StatusItemController` 注入 `NSApp.terminate(nil)`，
    /// 由 `PopoverPreviewWindowFactory` 在 UITEST 模式下注入测试 stub（避免真的退出测试进程）。
    var onExitApp: (() -> Void)?

    /// 单击回调（更新选中状态，不触发粘贴）。
    var onSingleClick: ((Int) -> Void)?

    /// 双击回调（触发粘贴流程）。
    var onDoubleClick: ((ClipItem) -> Void)?

    /// 由外部注入的剪贴项列表（不直接读取剪贴板存储）。
    let clips: [ClipItem]

    init(clips: [ClipItem])
    {
        self.clips = clips
        selectedIndex = clips.isEmpty ? -1 : 0
    }

    // MARK: - 选中状态

    func isSelected(index: Int) -> Bool
    {
        index == selectedIndex
    }

    func selectIndex(_ index: Int)
    {
        guard clips.indices.contains(index) else { return }
        selectedIndex = index
        shouldShowTextOnlyHint = false
        onSingleClick?(index)
    }

    // MARK: - 方向键导航

    func moveSelectionUp()
    {
        guard !clips.isEmpty, selectedIndex > 0 else { return }
        selectedIndex -= 1
    }

    func moveSelectionDown()
    {
        guard !clips.isEmpty, selectedIndex < clips.count - 1 else { return }
        selectedIndex += 1
    }

    // MARK: - 键盘事件

    func handleEnterKey()
    {
        guard clips.indices.contains(selectedIndex) else { return }
        let clip = clips[selectedIndex]
        onPasteTriggered?(clip)
        lastTriggeredClipIdForTesting = clip.id.uuidString
    }

    /// 双击处理（按 clip 查找）：文本类型触发粘贴回调，图片 / 文件路径类型显示提示。
    ///
    /// 使用 clip 而非 index，避免搜索过滤后 filteredClips 的 index 与 clips 的 index 不匹配
    /// 导致访问错误的 clip。
    /// - Parameter clip: 被双击的 ClipItem
    func handleDoubleClick(clip: ClipItem)
    {
        switch clip.content
        {
        case .text:
            shouldShowTextOnlyHint = false
            onPasteTriggered?(clip)
            lastTriggeredClipIdForTesting = clip.id.uuidString
        case .image, .filePath:
            shouldShowTextOnlyHint = true
            LogCategory.ui.info("UnifiedPastePanel double-click on non-text row, showing hint")
        }
    }

    func handleEscKey()
    {
        onEscPressed?()
    }
}
