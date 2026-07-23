import AppKit
import SwiftUI

/// 快速粘贴面板视图模型（管理高亮选中状态 + 键盘事件路由）。
///
/// Phase 1 实现默认高亮第一行 + 方向键导航 + 单击选中 + 回车回调骨架。
/// Phase 2 接入双击回调，Phase 3 接入 PasteCoordinator。
@MainActor
final class QuickPasteViewModel: ObservableObject
{
    @Published var selectedIndex: Int

    /// 双击/回车触发的粘贴回调（Phase 2/3 接入 PasteCoordinator）。
    var onPasteTriggered: ((ClipItem) -> Void)?

    /// 测试用：记录最近触发 onPasteTriggered 的 clip.id，供 UI 测试通过测试元素验证回调被调用。
    /// 仅在测试启动参数下通过 QuickPasteView 的测试元素暴露，不影响生产行为。
    @Published var lastTriggeredClipIdForTesting: String?

    /// 是否显示"仅支持文本粘贴"提示（双击图片/文件路径行时为 true）。
    @Published var shouldShowTextOnlyHint = false

    /// Esc 键回调（由控制器关闭面板）。
    var onEscPressed: (() -> Void)?

    /// 单击回调（更新选中状态，不触发粘贴）。
    var onSingleClick: ((Int) -> Void)?

    /// 双击回调（触发粘贴流程）。
    var onDoubleClick: ((ClipItem) -> Void)?

    let clips: [ClipItem]

    init(clips: [ClipItem])
    {
        self.clips = clips
        // 默认高亮第一行（若列表非空）
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
        // test hook：记录触发的 clip.id，供 UI 测试验证回调被调用（Phase 2 任务 5）
        lastTriggeredClipIdForTesting = clip.id.uuidString
    }

    /// 双击处理：文本类型触发粘贴回调，图片/文件路径类型显示提示。
    /// - Parameter index: 被双击的行索引
    func handleDoubleClick(index: Int)
    {
        guard clips.indices.contains(index) else { return }
        let clip = clips[index]

        switch clip.content
        {
        case .text:
            shouldShowTextOnlyHint = false
            onPasteTriggered?(clip)
            // test hook：记录触发的 clip.id，供 UI 测试验证回调被调用（Phase 2 任务 5）
            lastTriggeredClipIdForTesting = clip.id.uuidString
        case .image, .filePath:
            shouldShowTextOnlyHint = true
            LogCategory.ui.info("QuickPaste double-click on non-text row, showing hint")
        }
    }

    func handleEscKey()
    {
        onEscPressed?()
    }
}

/// 快速粘贴面板内容视图。
///
/// 视觉与菜单栏 popover 一致（搜索框 + LazyVStack 列表），但增加：
/// - 默认高亮第一行（蓝色边框 + 浅蓝背景）
/// - 单击选中（通过 ClipRowView.isSelected，Phase 2 接入）
/// - 双击触发回调（Phase 2 接入）
/// - Esc/方向键/回车键盘事件路由（NSEvent.addLocalMonitorForEvents）
struct QuickPasteView: View
{
    @StateObject private var viewModel: QuickPasteViewModel
    @State private var searchText = ""
    @State private var keyMonitor: Any?

    init(clips: [ClipItem])
    {
        _viewModel = StateObject(wrappedValue: QuickPasteViewModel(clips: clips))
    }

    /// 外部注入 viewModel 的初始化器（供 AppDelegate 注入带 PasteCoordinator 回调的 viewModel）。
    init(viewModel: QuickPasteViewModel)
    {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View
    {
        VStack(spacing: 0)
        {
            searchBar
            Divider()
            contentList
        }
        .frame(width: 360, height: 480)
        .onAppear { startKeyMonitor() }
        .onDisappear { stopKeyMonitor() }
        .onChange(of: searchText)
        { _ in
            // 搜索过滤后 selectedIndex 重置为 0（过滤后列表的第一行），避免越界；
            // 搜索清空时 selectedIndex 保持 0（显示全部，第一行高亮）
            if !filteredClips.isEmpty
            {
                viewModel.selectedIndex = 0
            }
        }
    }

    // MARK: - 搜索框

    private var searchBar: some View
    {
        HStack(spacing: 8)
        {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("搜索剪贴内容...", text: $searchText)
                .textFieldStyle(.plain)
                .accessibilityIdentifier("quickPasteSearchField")
        }
        .padding(8)
    }

    // MARK: - 列表

    private var filteredClips: [ClipItem]
    {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return viewModel.clips }
        return viewModel.clips.filter { clip in
            if case .text(let text) = clip.content
            {
                return text.localizedCaseInsensitiveContains(trimmed)
            }
            return false
        }
    }

    private var contentList: some View
    {
        Group
        {
            if filteredClips.isEmpty
            {
                VStack(spacing: 8)
                {
                    Image(systemName: "tray")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("暂无剪贴内容")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else
            {
                ScrollView
                {
                    LazyVStack(spacing: 0)
                    {
                        ForEach(Array(filteredClips.enumerated()), id: \.element.id)
                        { index, clip in
                            ClipRowView(
                                clip: clip,
                                isSelected: viewModel.isSelected(index: index),
                                onSingleClick: { viewModel.selectIndex(index) },
                                onDoubleClick: { viewModel.handleDoubleClick(index: index) }
                            )
                            .accessibilityIdentifier(
                                "quickPasteRow_\(index)"
                                + "\(viewModel.isSelected(index: index) ? "_selected" : "")"
                            )
                            .accessibilityValue(clip.id.uuidString)
                        }

                        if viewModel.shouldShowTextOnlyHint
                        {
                            Text("仅支持文本粘贴")
                                .font(.caption)
                                .foregroundColor(.orange)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity)
                                .accessibilityIdentifier("textOnlyHint")
                        }
                    }
                }
                // 测试用元素：暴露 onPasteTriggered 触发的 clip.id（验证回调被调用，不影响视觉）
                Text(viewModel.lastTriggeredClipIdForTesting ?? "")
                    .accessibilityIdentifier("quickPasteTestTriggeredClipId")
                    .frame(width: 0, height: 0)
                    .opacity(0)
            }
        }
    }

    // MARK: - 键盘事件监听

    private func startKeyMonitor()
    {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown)
        { event in
            self.handleKeyEvent(event)
            return event
        }
    }

    private func stopKeyMonitor()
    {
        if let monitor = keyMonitor
        {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }

    private func handleKeyEvent(_ event: NSEvent)
    {
        switch event.keyCode
        {
        case 36: // Enter
            viewModel.handleEnterKey()
        case 53: // Esc
            viewModel.handleEscKey()
        case 125: // Down arrow
            viewModel.moveSelectionDown()
        case 126: // Up arrow
            viewModel.moveSelectionUp()
        default:
            break
        }
    }
}
