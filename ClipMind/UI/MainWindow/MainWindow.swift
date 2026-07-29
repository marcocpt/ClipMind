import SwiftUI

struct MainWindow: View {
    @State private var selectedClip: ClipItem?
    @State private var searchText = ""
    @State private var searchResults: [ClipItem] = []
    @State private var isSearching = false
    @State private var sourceFilterSelection = SourceFilterSelection(allApps: [])
    @StateObject private var clipStore = ClipStore()
    @ObservedObject private var tagStore: TagStore
    @State private var isMigrationBannerDismissed = false

    init(tagStore: TagStore) {
        self._tagStore = ObservedObject(initialValue: tagStore)
    }

    private var allClips: [ClipItem] {
        ClipTestData.isUITesting ? ClipTestData.previewClips : clipStore.clips
    }

    private var sourceApps: [String]
    {
        SourceAppExtractor.extract(from: allClips)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                searchPanel
                Divider()
                migrationBanner
                contentArea
            }
            .frame(minWidth: LayoutConstants.sidebarMinWidth)
            DetailPanel(clip: selectedClip) { updated in
                selectedClip = updated
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: openSettings, label: {
                    Image(systemName: "gearshape")
                })
                .accessibilityIdentifier("settingsButton")
            }
        }
        .frame(minWidth: LayoutConstants.mainWindowMinWidth, minHeight: LayoutConstants.mainWindowMinHeight)
        .onAppear {
            sourceFilterSelection = SourceFilterSelection(allApps: Set(sourceApps))
            if CommandLine.arguments.contains("--UITEST_AUTO_SELECT_FIRST") {
                selectedClip = allClips.first
            }
        }
        .onChange(of: sourceApps) { newApps in
            sourceFilterSelection = SourceFilterSelection(allApps: Set(newApps))
        }
    }

    private var searchPanel: some View {
        HStack(spacing: 12) {
            SearchBar(text: $searchText, onCommit: performSearch)
            SourceFilter(
                selection: $sourceFilterSelection,
                availableApps: sourceApps
            )
        }
        .padding(12)
    }

    /// F1.14 标签迁移失败 banner：在不遮挡历史列表的顶部区域显示固定安全错误、
    /// `tagMigrationRetryButton` 和关闭动作。重试调用 `tagStore.retry()`，
    /// 关闭只隐藏本次提示而不篡改最近成功快照。
    @ViewBuilder
    private var migrationBanner: some View
    {
        if tagStore.failedOperation == .migration, !isMigrationBannerDismissed
        {
            HStack(spacing: 8)
            {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.white)
                Text(tagStore.errorMessage ?? "标签迁移失败，请重试")
                    .foregroundColor(.white)
                    .font(.caption)
                    .lineLimit(1)
                Spacer()
                Button("重试")
                {
                    isMigrationBannerDismissed = false
                    tagStore.retry()
                }
                .accessibilityIdentifier("tagMigrationRetryButton")
                Button
                {
                    isMigrationBannerDismissed = true
                } label: {
                    Image(systemName: "xmark")
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("关闭迁移提示")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.orange)
        }
    }

    @ViewBuilder
    private var contentArea: some View {
        if isSearching {
            SearchResultsView(
                results: filteredSearchResults,
                onSelect: { clip in
                    selectedClip = clip
                },
                isSourceFilterActive: !sourceFilterSelection.isAllSelected,
                tagStore: tagStore
            )
        } else {
            HistoryListView(
                selectedClip: $selectedClip,
                sourceFilter: sourceFilterSelection.selectedSources,
                tagStore: tagStore
            )
        }
    }

    /// 搜索结果按来源 App 过滤
    private var filteredSearchResults: [ClipItem]
    {
        if sourceFilterSelection.isAllSelected
        {
            return searchResults
        }
        return searchResults.filter { sourceFilterSelection.selectedSources.contains($0.sourceAppName) }
    }

    /// 执行搜索（UI 测试模式下为文本匹配；生产环境后续接入 SearchService）
    private func performSearch(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            isSearching = false
            searchResults = []
            return
        }
        isSearching = true
        searchResults = allClips.filter { clip in
            if case .text(let text) = clip.content {
                return text.localizedCaseInsensitiveContains(trimmed)
            }
            return false
        }
    }

    /// 打开设置面板。
    ///
    /// 生产环境通过 macOS 13 的 `showSettingsWindow:` 选择器触发 SwiftUI Settings 场景。
    /// UI 测试模式下（CI 环境）Settings 场景无法通过 sendAction 正常创建窗口，
    /// 因此改用独立 NSWindow 承载 SettingsView，确保 XCUITest 能可靠定位元素。
    private func openSettings() {
        if CommandLine.arguments.contains("--UITEST_SHOW_MAIN_WINDOW") {
            showSettingsInStandaloneWindow()
            return
        }
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    /// 在独立 NSWindow 中显示设置视图（UI 测试模式专用）。
    private func showSettingsInStandaloneWindow() {
        for window in NSApp.windows where window.title == "ClipMind Settings" {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 350),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "ClipMind Settings"
        window.contentViewController = NSHostingController(rootView: SettingsView())
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
