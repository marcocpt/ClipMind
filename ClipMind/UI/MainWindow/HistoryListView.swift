import SwiftUI

struct HistoryListView: View
{
    @Binding var selectedClip: ClipItem?
    let sourceFilter: Set<String>
    @StateObject private var clipStore = ClipStore()

    /// F1.14 共享标签状态。为 nil 时不显示标签条（UI 测试或无标签场景）。
    var tagStore: TagStore?

    private var clips: [ClipItem]
    {
        ClipTestData.isUITesting ? ClipTestData.previewClips : clipStore.clips
    }

    private var filteredClips: [ClipItem]
    {
        if sourceFilter.isEmpty || sourceFilter.count == Set(clips.map(\.sourceAppName)).count
        {
            return clips
        }
        return clips.filter { sourceFilter.contains($0.sourceAppName) }
    }

    var body: some View
    {
        if clips.isEmpty
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
        } else if filteredClips.isEmpty {
            VStack(spacing: 8)
            {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                Text("当前筛选条件下无内容")
                    .font(.title3)
                    .foregroundColor(.secondary)
                Text("尝试调整来源筛选条件")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityIdentifier("historyFilterEmptyState")
        } else {
            // F1.14：使用 ScrollView + LazyVStack。
            // List 在 NavigationView 中会拦截子视图 Button 的 tap gesture，
            // 导致标签 pill 不可点击。ScrollView + LazyVStack 不存在此限制。
            //
            // LazyVStack 懒加载导致 typeTag_ 计数只返回可见行，因此把
            // filteredClips.count 作为 ScrollView 自身的 accessibilityValue 暴露给 UI 测试。
            // 之前用隐藏 Text（frame(0,0)+opacity(0)）承载 count，在 CI runner 上被
            // accessibility tree 排除（本地能读到、CI 读到 0，环境差异不可靠）。
            // 改为挂在 ScrollView 上避免依赖隐藏元素。
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredClips) { clip in
                        ClipRowView(
                            clip: clip,
                            onSingleClick: { selectedClip = clip },
                            tagStore: tagStore
                        )
                        .accessibilityElement(children: .contain)
                    }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("historyList")
            .accessibilityValue("\(filteredClips.count)")
        }
    }
}
