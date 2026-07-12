import SwiftUI

struct DetailPanel: View {
    let clip: ClipItem?

    var body: some View {
        if let clip = clip {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(contentPreview(for: clip))
                        .font(.body)
                    Divider()
                    HStack {
                        Label(clip.sourceAppName, systemImage: "app")
                        Spacer()
                        Label(timeAgo(for: clip), systemImage: "clock")
                    }
                    .foregroundColor(.secondary)
                    .font(.caption)
                }
                .padding()
            }
        } else {
            VStack(spacing: 8) {
                Image(systemName: "doc.text")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                Text("选择一条剪贴内容查看详情")
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func contentPreview(for clip: ClipItem) -> String {
        switch clip.content {
        case .text(let text):
            return text
        case .image:
            return "[图片]"
        case .filePath(let urls):
            return urls.map(\.lastPathComponent).joined(separator: ", ")
        }
    }

    private func timeAgo(for clip: ClipItem) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: clip.timestamp, relativeTo: Date())
    }
}
