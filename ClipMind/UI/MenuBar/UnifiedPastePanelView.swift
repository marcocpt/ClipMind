import AppKit
import SwiftUI

/// 统一粘贴面板视图（F1.11 Phase 1）。
///
/// 合并 F1.9 `QuickPasteView` 与 `PopoverView`，承载两个场景共用的列表渲染、键盘事件、
/// 选中态逻辑。底部工具栏通过 `showsBottomBar` 外部参数控制显隐：
/// - 菜单栏弹窗场景（StatusItemController 包装）：`showsBottomBar = true`
/// - 快捷键面板场景（QuickPastePanelController 包装）：`showsBottomBar = true`（F1.11 后续 bug 修复对齐）
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

    /// F1.14 共享标签状态。为 nil 时不显示标签条。
    private let tagStore: TagStore?

    init(
        viewModel: UnifiedPastePanelViewModel,
        showsBottomBar: Bool,
        accessibilityPrefix: String,
        tagStore: TagStore? = nil
    )
    {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.showsBottomBar = showsBottomBar
        self.accessibilityPrefix = accessibilityPrefix
        self.tagStore = tagStore
        if let store = tagStore
        {
            viewModel.attachTagStore(store)
        }
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
            if !searchFilteredClips.isEmpty
            {
                viewModel.selectedIndex = 0
            }
        }
        .onChange(of: viewModel.sourceFilterSelection.selectedSources)
        { _ in
            if !searchFilteredClips.isEmpty
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
            Button
            {
                viewModel.showFilterOverlay.toggle()
            } label: {
                let iconName = viewModel.isSourceFilterActive
                    ? "line.3.horizontal.decrease.circle.fill"
                    : "line.3.horizontal.decrease.circle"
                Image(systemName: iconName)
                    .foregroundColor(viewModel.isSourceFilterActive ? .accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $viewModel.showFilterOverlay, arrowEdge: .bottom)
            {
                SourceFilterOverlay(
                    selection: $viewModel.sourceFilterSelection,
                    availableApps: viewModel.sourceApps
                )
            }
            .accessibilityLabel("来源筛选")
            .accessibilityAddTraits(.isButton)
        }
        .padding(8)
    }

    // MARK: - 列表

    /// 先按来源过滤，再按搜索文本过滤。
    private var searchFilteredClips: [ClipItem]
    {
        let sourceFiltered = viewModel.filteredClips
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return sourceFiltered }
        return sourceFiltered.filter { clip in
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
            if searchFilteredClips.isEmpty
            {
                VStack(spacing: 8)
                {
                    if viewModel.isSourceFilterActive
                    {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.system(size: 32))
                            .foregroundColor(.secondary)
                        Text("无匹配的剪贴项")
                            .foregroundColor(.secondary)
                    } else
                    {
                        Image(systemName: "tray")
                            .font(.system(size: 32))
                            .foregroundColor(.secondary)
                        Text("暂无剪贴内容")
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else
            {
                ScrollView
                {
                    LazyVStack(spacing: 0)
                    {
                        ForEach(Array(searchFilteredClips.enumerated()), id: \.element.id)
                        { index, clip in
                            ClipRowView(
                                clip: clip,
                                isSelected: viewModel.isSelected(index: index),
                                onSingleClick: { viewModel.selectIndex(index) },
                                onDoubleClick: { viewModel.handleDoubleClick(clip: clip) },
                                tagStore: tagStore
                            )
                            .accessibilityElement(children: .contain)
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
                // F1.14：把 searchFilteredClips.count 作为 ScrollView 自身的 accessibilityValue
                // 暴露给 UI 测试。之前用隐藏 Text（frame(0,0)+opacity(0)）承载 count，
                // 在 CI runner 上被 accessibility tree 排除（本地能读到、CI 读到 0，环境差异不可靠）。
                // identifier 用 "\(accessibilityPrefix)List"（popoverList / quickPasteList）。
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("\(accessibilityPrefix)List")
                .accessibilityValue("\(searchFilteredClips.count)")
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
                // 「查看全部」：先关闭菜单栏弹窗，再发送打开主窗口信号。
                // F1.11 Phase 3 任务 8 修复：调整顺序避免 didBecomeKeyNotification 监听器
                // 与 window.close() 的时序竞争。先 close 触发 willCloseNotification 移除监听器，
                // 再发送通知让主窗口成为 key，避免监听器 orderOut 主窗口。
                viewModel.onEscPressed?()
                NotificationCenter.default.post(name: .openMainWindow, object: nil)
            },
            onSettings:
            {
                // 「配置」：先关闭菜单栏弹窗，再发送打开设置窗口信号（时序修复同上）。
                viewModel.onEscPressed?()
                NotificationCenter.default.post(name: .openSettingsWindow, object: nil)
            },
            onExit:
            {
                // F1.11 Bug Fix：「退出」按钮退出整个应用（原为关闭弹窗，与 Esc 重复）
                // 由控制器注入 NSApp.terminate(nil)，UITEST 模式下注入测试 stub
                viewModel.onExitApp?()
            }
        )
    }

    // MARK: - 键盘事件监听

    private func startKeyMonitor()
    {
        // F1.11 Bug Fix：通过 PanelKeyEventHandler 路由键盘事件。
        // ESC 返回 nil 被消费，避免传播到 NSResponder.cancelOperation 触发 NSBeep。
        let handler = PanelKeyEventHandler(
            onEnter: { viewModel.handleEnterKey() },
            onEsc: { viewModel.handleEscKey() },
            onMoveDown: { viewModel.moveSelectionDown() },
            onMoveUp: { viewModel.moveSelectionUp() }
        )
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown)
        { event in
            handler.handle(event)
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
}
