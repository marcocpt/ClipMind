import SwiftUI

/// 搜索结果列表。
///
/// 显示搜索查询返回的 ClipItem 列表，每项包含类型标签、内容预览、来源和时间。
/// 对应 UI-AC-06 搜索交互：结果列表按相关度排序。
struct SearchResultsView: View {
    let results: [ClipItem]
    let onSelect: (ClipItem) -> Void

    var body: some View {
        if results.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 36))
                    .foregroundColor(.secondary)
                Text("未找到匹配内容")
                    .font(.title3)
                    .foregroundColor(.secondary)
                Text("尝试输入其他关键词")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityIdentifier("searchEmptyState")
        } else {
            List(results) { clip in
                ClipRowView(clip: clip)
                    .contentShape(Rectangle())
                    .onTapGesture { onSelect(clip) }
            }
            .accessibilityIdentifier("searchResultsList")
        }
    }
}
