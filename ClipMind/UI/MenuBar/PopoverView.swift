import SwiftUI

struct PopoverView: View {
    @State private var searchText = ""
    private let clips: [ClipItem] = []

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

    private var contentList: some View {
        Group {
            if clips.isEmpty {
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
                        ForEach(clips) { clip in
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
