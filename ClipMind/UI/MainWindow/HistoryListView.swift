import SwiftUI

struct HistoryListView: View
{
    @Binding var selectedClip: ClipItem?

    /// 原始全部条目（未经筛选），用于区分「无历史」与「条件无匹配」。
    let allClips: [ClipItem]

    /// 经 `CompositeClipFilter` 筛选后的条目。
    let filteredClips: [ClipItem]

    /// F1.14 共享标签状态。为 nil 时不显示标签条（UI 测试或无标签场景）。
    var tagStore: TagStore?

    private var listState: ClipListState
    {
        ClipListState.resolve(allClips: allClips, filteredClips: filteredClips)
    }

    var body: some View
    {
        switch listState
        {
        case .noHistory:
            noHistoryView
        case .noMatches:
            noMatchesView
        case .results:
            resultsView
        }
    }

    // MARK: - 空状态

    private var noHistoryView: some View
    {
        VStack(spacing: 8)
        {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("暂无剪贴历史")
                .font(.title3)
                .foregroundColor(.secondary)
            Text("复制任何内容，它将自动出现在这里")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("historyEmptyState")
    }

    private var noMatchesView: some View
    {
        VStack(spacing: 8)
        {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("没有符合当前条件的剪贴项")
                .font(.title3)
                .foregroundColor(.secondary)
            Text("尝试调整搜索、来源或标签筛选条件")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("historyFilterEmptyState")
    }

    // MARK: - 结果列表

    private var resultsView: some View
    {
        // F1.14：使用 ScrollView + LazyVStack。
        // List 在 NavigationView 中会拦截子视图 Button 的 tap gesture，
        // 导致标签 pill 不可点击。ScrollView + LazyVStack 不存在此限制。
        //
        // LazyVStack 懒加载导致 typeTag_ 计数只返回可见行，因此把
        // filteredClips.count 作为 ScrollView 自身的 accessibilityValue 暴露给 UI 测试。
        ScrollView
        {
            LazyVStack(spacing: 0)
            {
                ForEach(filteredClips)
                { clip in
                    ClipRowView(
                        clip: clip,
                        onSingleClick: { selectedClip = clip },
                        tagStore: tagStore
                    )
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("clipRow_\(clip.id.uuidString)")
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("historyList")
        .accessibilityValue("\(filteredClips.count)")
    }
}
