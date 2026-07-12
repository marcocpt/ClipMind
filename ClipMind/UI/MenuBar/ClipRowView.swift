import SwiftUI

struct ClipRowView: View {
    let clip: ClipItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(contentPreview)
                .font(.system(size: 13))
                .lineLimit(2)
                .foregroundColor(.primary)
            HStack(spacing: 8) {
                Text(clip.sourceAppName)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text(timeAgo)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(Color.gray.opacity(0.15))
        .cornerRadius(12)
    }

    private var contentPreview: String {
        switch clip.content {
        case .text(let text):
            return text
        case .image:
            return "[图片]"
        case .filePath(let urls):
            return urls.map(\.lastPathComponent).joined(separator: ", ")
        }
    }

    private var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: clip.timestamp, relativeTo: Date())
    }
}
