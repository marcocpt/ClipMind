import AppKit
import SwiftUI

/// 统一粘贴面板视图（F1.11 Phase 1）。
///
/// 合并 F1.9 `QuickPasteView` 与 `PopoverView`，承载两个场景共用的列表渲染、键盘事件、
/// 选中态逻辑。底部工具栏通过 `showsBottomBar` 外部参数控制显隐：
/// - 菜单栏弹窗场景（StatusItemController 包装）：`showsBottomBar = true`
/// - 快捷键面板场景（QuickPastePanelController 包装）：`showsBottomBar = false`
///
/// 视图本身不读取剪贴板存储，剪贴项列表通过 `UnifiedPastePanelViewModel.clips` 注入。
///
/// 设计文档第 3.2 节、第 4.1 节。
struct UnifiedPastePanelView: View
{
    @StateObject private var viewModel: UnifiedPastePanelViewModel
    @State private var searchText = ""
    @State private var keyMonitor: Any?

    /// 底部工具栏可见性（菜单栏弹窗场景为 true，快捷键场景为 false）。
    private let showsBottomBar: Bool

    /// 辅助功能标识符前缀（菜单栏弹窗用 `popover`，快捷键用 `quickPaste`，保持 F1.9 已有标识符不变）。
    private let accessibilityPrefix: String

    init(viewModel: UnifiedPastePanelViewModel, showsBottomBar: Bool, accessibilityPrefix: String)
    {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.showsBottomBar = showsBottomBar
        self.accessibilityPrefix = accessibilityPrefix
    }

    var body: some View
    {
        VStack(spacing: 0)
        {
            searchBar
            Divider()
            contentList
            if showsBottomBar
            {
                Divider()
                bottomToolbar
            }
        }
        .frame(width: 360, height: 480)
        .onAppear { startKeyMonitor() }
        .onDisappear { stopKeyMonitor() }
        .onChange(of: searchText)
        { _ in
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
                .accessibilityIdentifier("\(accessibilityPrefix)SearchField")
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
                                onDoubleClick: { viewModel.handleDoubleClick(clip: clip) }
                            )
                            .accessibilityIdentifier(
                                "\(accessibilityPrefix)Row_\(index)"
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
                Text(viewModel.lastTriggeredClipIdForTesting ?? "")
                    .accessibilityIdentifier("\(accessibilityPrefix)TestTriggeredClipId")
                    .frame(width: 0, height: 0)
                    .opacity(0)
            }
        }
    }

    // MARK: - 底部工具栏（F1.11 Phase 3 任务 4 集成 BottomToolbarView）

    private var bottomToolbar: some View
    {
        BottomToolbarView(
            onViewAll:
            {
                // 「查看全部」：发送打开主窗口信号 + 关闭菜单栏弹窗
                NotificationCenter.default.post(name: .openMainWindow, object: nil)
                viewModel.onEscPressed?()
            },
            onSettings:
            {
                // 「配置」：发送打开设置窗口信号 + 关闭菜单栏弹窗
                NotificationCenter.default.post(name: .openSettingsWindow, object: nil)
                viewModel.onEscPressed?()
            },
            onExit:
            {
                // 「退出」：仅关闭菜单栏弹窗，不发送任何通知
                viewModel.onEscPressed?()
            }
        )
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
