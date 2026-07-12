import SwiftUI

struct HistoryListView: View {
    @Binding var selectedClip: ClipItem?
    @State private var clips: [ClipItem] = ClipTestData.isUITesting ? ClipTestData.previewClips : []

    var body: some View {
        if clips.isEmpty {
            VStack(spacing: 8) {
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
        } else {
            List(clips) { clip in
                ClipRowView(clip: clip)
                    .contentShape(Rectangle())
                    .onTapGesture { selectedClip = clip }
            }
        }
    }
}
