import SwiftUI

struct PopoverView: View {
    @State private var searchText = ""
    @State private var clips: [ClipItem] = ClipTestData.isUITesting ? ClipTestData.previewClips : []

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider()
            contentList
            Divider()
            bottomBar
        }
        .frame(width: 360, height: 480)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("搜索剪贴内容...", text: $searchText)
                .textFieldStyle(.plain)
                .accessibilityIdentifier("popoverSearchField")
        }
        .padding(8)
    }

    private var filteredClips: [ClipItem] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return clips }
        return clips.filter { clip in
            if case .text(let text) = clip.content {
                return text.localizedCaseInsensitiveContains(trimmed)
            }
            return false
        }
    }

    private var contentList: some View {
        Group {
            if filteredClips.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("暂无剪贴内容")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredClips) { clip in
                            ClipRowView(clip: clip)
                        }
                    }
                }
            }
        }
    }

    private var bottomBar: some View {
        HStack {
            Button("查看全部") {
                NotificationCenter.default.post(name: .openMainWindow, object: nil)
            }
            .accessibilityIdentifier("viewAllButton")
            Spacer()
        }
        .padding(8)
    }
}
