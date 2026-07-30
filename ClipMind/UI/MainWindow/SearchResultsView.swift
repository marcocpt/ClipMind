import SwiftUI

/// 搜索结果列表。
///
/// 显示经 `CompositeClipFilter` 筛选后的 ClipItem 列表，每项包含类型标签、内容预览、来源和时间。
/// 与 `HistoryListView` 使用相同的 `filteredClips`，空状态文案根据激活的筛选条件区分，
/// 保证纯搜索无匹配时仍显示「未找到匹配内容」（兼容 SearchUITests）。
struct SearchResultsView: View
{
    /// 经 `CompositeClipFilter` 筛选后的条目，与 HistoryListView 共享同一结果集。
    let filteredClips: [ClipItem]
    let onSelect: (ClipItem) -> Void

    /// F1.14 共享标签状态。为 nil 时不显示标签条。
    var tagStore: TagStore?

    /// 当前筛选意图，用于选择空状态文案。
    var filterIntent: ClipFilterIntent

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

    /// 空状态文案根据激活的筛选条件选择：
    /// - 纯搜索：`未找到匹配内容`（兼容 SearchUITests）
    /// - 仅来源：`来源过滤无匹配`
    /// - 仅标签：`标签过滤无匹配`
    /// - 来源+标签：`没有符合当前条件的剪贴项`
    private var emptyState: some View
    {
        let (title, message) = emptyStateCopy
        return VStack(spacing: 8)
        {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 36))
                .foregroundColor(.secondary)
            Text(title)
                .font(.title3)
                .foregroundColor(.secondary)
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("searchFilterEmptyState")
    }

    private var emptyStateCopy: (title: String, message: String)
    {
        switch (filterIntent.isSourceFilterActive, filterIntent.isTagFilterActive)
        {
        case (false, false):
            return ("未找到匹配内容", "尝试输入其他关键词")
        case (true, false):
            return ("来源过滤无匹配", "当前来源下无匹配内容，尝试切换来源")
        case (false, true):
            return ("标签过滤无匹配", "当前标签下无匹配内容，尝试调整标签筛选")
        case (true, true):
            return ("没有符合当前条件的剪贴项", "尝试调整搜索、来源或标签筛选条件")
        }
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
                        .accessibilityIdentifier("clipRow_\(clip.id.uuidString)")
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("searchResultsList")
        .accessibilityValue("\(filteredClips.count)")
    }
}
