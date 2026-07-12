import SwiftUI

/// 主窗口搜索栏。
///
/// 提供搜索输入框，输入变化后防抖 300ms 触发搜索回调。
/// 对应设计规范 3.5 节搜索流程和 UI-AC-06 搜索交互。
struct SearchBar: View {
    @Binding var text: String
    var onCommit: (String) -> Void

    @State private var debounceTask: Task<Void, Never>?

    /// 防抖间隔（毫秒）
    private let debounceMillis: UInt64 = 300

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("搜索剪贴内容...", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .accessibilityIdentifier("mainSearchField")
                .onChange(of: text) { newValue in
                    scheduleDebouncedSearch(newValue)
                }
                .onSubmit {
                    debounceTask?.cancel()
                    onCommit(text)
                }
            if !text.isEmpty {
                Button(action: clearSearch) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("clearSearchButton")
            }
        }
        .padding(10)
        .background(Color.gray.opacity(0.12))
        .cornerRadius(12)
    }

    private func scheduleDebouncedSearch(_ query: String) {
        debounceTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            onCommit("")
            return
        }
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: debounceMillis * 1_000_000)
            if !Task.isCancelled {
                await MainActor.run { onCommit(query) }
            }
        }
    }

    private func clearSearch() {
        text = ""
        onCommit("")
    }
}
