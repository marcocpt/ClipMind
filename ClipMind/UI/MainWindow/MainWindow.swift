import SwiftUI

struct MainWindow: View {
    @State private var selectedClip: ClipItem?
    @State private var searchText = ""
    @State private var searchResults: [ClipItem] = []
    @State private var isSearching = false
    @State private var selectedSourceApp: String?
    @State private var allClips: [ClipItem] = ClipTestData.isUITesting ? ClipTestData.previewClips : []

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                searchPanel
                Divider()
                contentArea
            }
            DetailPanel(clip: selectedClip)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: openSettings, label: {
                    Image(systemName: "gearshape")
                })
                .accessibilityIdentifier("settingsButton")
            }
        }
        .frame(minWidth: 800, minHeight: 500)
    }

    private var searchPanel: some View {
        HStack(spacing: 12) {
            SearchBar(text: $searchText, onCommit: performSearch)
            SourceFilter(
                selectedApp: $selectedSourceApp,
                availableApps: ClipTestData.previewSourceApps
            )
        }
        .padding(12)
    }

    @ViewBuilder
    private var contentArea: some View {
        if isSearching {
            SearchResultsView(results: filteredSearchResults) { clip in
                selectedClip = clip
            }
        } else {
            HistoryListView(selectedClip: $selectedClip)
        }
    }

    /// 搜索结果按来源 App 过滤
    private var filteredSearchResults: [ClipItem] {
        guard let sourceApp = selectedSourceApp else { return searchResults }
        return searchResults.filter { $0.sourceAppName == sourceApp }
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
    /// 通过 macOS 13 的 `showSettingsWindow:` 选择器触发 SwiftUI Settings 场景。
    /// 部署目标为 macOS 13.0，无需降级到已废弃的 `showPreferencesWindow:`。
    private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
}
