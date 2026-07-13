import SwiftUI

struct MainWindow: View {
    @State private var selectedClip: ClipItem?
    @State private var searchText = ""
    @State private var searchResults: [ClipItem] = []
    @State private var isSearching = false
    @State private var selectedSourceApp: String?
    @StateObject private var clipStore = ClipStore()

    private var allClips: [ClipItem] {
        ClipTestData.isUITesting ? ClipTestData.previewClips : clipStore.clips
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                searchPanel
                Divider()
                contentArea
            }
            .frame(minWidth: 700)
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
        .frame(minWidth: 980, minHeight: 500)
        .onAppear {
            if CommandLine.arguments.contains("--UITEST_AUTO_SELECT_FIRST") {
                selectedClip = allClips.first
            }
        }
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
