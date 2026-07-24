import SwiftUI

struct MainWindow: View {
    @State private var selectedClip: ClipItem?
    @State private var searchText = ""
    @State private var searchResults: [ClipItem] = []
    @State private var isSearching = false
    @State private var selectedSourceApp: String?
    @StateObject private var clipStore = ClipStore()
    /// 浮层可见性 test hook（通过 @AppStorage 监听 UserDefaults 变化）。
    /// NSPanel(.nonactivatingPanel) 在 CI 中无法被 XCUITest 可靠检测，主窗口元素反映状态。
    /// 使用 @AppStorage 而非 @ObservedObject/OverlayTestState：
    /// @AppStorage 直接绑定 UserDefaults，变化由系统 KVO 机制驱动，
    /// 比 Combine objectWillChange 在 CI 环境中更可靠（@StateObject/@ObservedObject
    /// 的 objectWillChange 在 CI 中可能因 SwiftUI View 重建时序问题丢失订阅）。
    @AppStorage("UITest_overlayVisible") private var isOverlayVisibleForTest = false

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
            if CommandLine.arguments.contains("--UITEST_AUTO_SELECT_FIRST") {
                selectedClip = allClips.first
            }
        }
        // 浮层可见性 test hook 元素（隐藏，不影响视觉）。
        // 值为 "1" 表示浮层可见，"0" 表示不可见。供 QuickPasteOverlayUITests 检测。
        Text(isOverlayVisibleForTest ? "1" : "0")
            .accessibilityIdentifier("quickPasteTestOverlayVisible")
            // 使用 1x1 pt + 极低透明度而非 0x0/opacity:0，
            // 因为 CI 环境中 XCUITest 无法检测 0 尺寸或 0 透明度元素的 label 变化。
            .frame(width: 1, height: 1)
            .opacity(0.01)
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
