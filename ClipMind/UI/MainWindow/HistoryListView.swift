import SwiftUI

struct HistoryListView: View
{
    @Binding var selectedClip: ClipItem?
    let sourceFilter: Set<String>
    @StateObject private var clipStore = ClipStore()

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
            List(filteredClips) { clip in
                ClipRowView(clip: clip, onSingleClick: { selectedClip = clip })
            }
            .accessibilityIdentifier("historyList")
        }
    }
}
