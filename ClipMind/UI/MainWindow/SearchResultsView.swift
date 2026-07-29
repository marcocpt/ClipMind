import SwiftUI

/// 搜索结果列表。
///
/// 显示搜索查询返回的 ClipItem 列表，每项包含类型标签、内容预览、来源和时间。
/// 对应 UI-AC-06 搜索交互：结果列表按相关度排序。
/// 空状态区分「来源过滤无匹配」与「搜索无结果」。
struct SearchResultsView: View
{
    let results: [ClipItem]
    let onSelect: (ClipItem) -> Void

    /// 是否激活了来源过滤（非「全部」状态）。
    var isSourceFilterActive: Bool = false

    /// F1.14 共享标签状态。为 nil 时不显示标签条。
    var tagStore: TagStore?

    var body: some View
    {
        if results.isEmpty
        {
            VStack(spacing: 8)
            {
                Image(systemName: isSourceFilterActive ? "line.3.horizontal.decrease.circle" : "magnifyingglass")
                    .font(.system(size: 36))
                    .foregroundColor(.secondary)
                Text(isSourceFilterActive ? "来源过滤无匹配" : "未找到匹配内容")
                    .font(.title3)
                    .foregroundColor(.secondary)
                Text(isSourceFilterActive ? "当前来源下无匹配内容，尝试切换来源" : "尝试输入其他关键词")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityIdentifier("searchEmptyState")
        } else {
            List(results)
            { clip in
                ClipRowView(clip: clip, tagStore: tagStore)
                    .contentShape(Rectangle())
                    .onTapGesture { onSelect(clip) }
            }
            .accessibilityIdentifier("searchResultsList")
        }
    }
}
