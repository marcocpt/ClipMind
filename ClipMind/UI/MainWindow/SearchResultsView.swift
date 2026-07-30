import SwiftUI

/// 搜索结果列表。
///
/// 显示经 `CompositeClipFilter` 筛选后的 ClipItem 列表，每项包含类型标签、内容预览、来源和时间。
/// 与 `HistoryListView` 使用相同的 `filteredClips`，空状态区分「条件无匹配」。
struct SearchResultsView: View
{
    /// 经 `CompositeClipFilter` 筛选后的条目，与 HistoryListView 共享同一结果集。
    let filteredClips: [ClipItem]
    let onSelect: (ClipItem) -> Void

    /// F1.14 共享标签状态。为 nil 时不显示标签条。
    var tagStore: TagStore?

    var body: some View
    {
        if filteredClips.isEmpty
        {
            emptyState
        } else {
            resultsList
        }
    }

    // MARK: - 空状态

    private var emptyState: some View
    {
        VStack(spacing: 8)
        {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 36))
                .foregroundColor(.secondary)
            Text("没有符合当前条件的剪贴项")
                .font(.title3)
                .foregroundColor(.secondary)
            Text("尝试调整搜索、来源或标签筛选条件")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("searchFilterEmptyState")
    }

    // MARK: - 结果列表

    private var resultsList: some View
    {
        // F1.14：使用 ScrollView + LazyVStack 与 HistoryListView 保持一致，
        // 避免 List 拦截 ClipRowView 内标签 pill 的 tap gesture。
        ScrollView
        {
            LazyVStack(spacing: 0)
            {
                ForEach(filteredClips)
                { clip in
                    ClipRowView(clip: clip, tagStore: tagStore)
                        .contentShape(Rectangle())
                        .onTapGesture { onSelect(clip) }
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("clipRow")
                        .accessibilityValue(clip.id.uuidString)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("searchResultsList")
        .accessibilityValue("\(filteredClips.count)")
    }
}
