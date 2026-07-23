import SwiftUI

struct ClipRowView: View
{
    let clip: ClipItem

    /// 是否高亮选中（F1.9 快速粘贴面板使用，菜单栏 popover 不传默认 false）。
    var isSelected: Bool = false

    /// 单击回调（F1.9 快速粘贴面板使用，菜单栏 popover 不传即 nil）。
    var onSingleClick: (() -> Void)?

    /// 双击回调（F1.9 快速粘贴面板使用，菜单栏 popover 不传即 nil）。
    var onDoubleClick: (() -> Void)?

    var body: some View
    {
        VStack(alignment: .leading, spacing: 6)
        {
            HStack(spacing: 8)
            {
                TypeTagView(contentType: clip.contentType)
                Spacer()
            }
            Text(contentPreview)
                .font(.system(size: 13))
                .lineLimit(2)
                .foregroundColor(.primary)
            HStack(spacing: 8)
            {
                Text(clip.sourceAppName)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text(timeAgo)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(backgroundColor)
        .overlay(borderOverlay)
        .cornerRadius(12)
        .contentShape(Rectangle())
        .onTapGesture(count: 1)
        {
            onSingleClick?()
        }
        .onTapGesture(count: 2)
        {
            onDoubleClick?()
        }
    }

    private var backgroundColor: Color
    {
        isSelected ? Color.accentColor.opacity(0.2) : Color.gray.opacity(0.15)
    }

    private var borderOverlay: some View
    {
        Group
        {
            if isSelected
            {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.accentColor, lineWidth: 2)
            } else
            {
                Color.clear
            }
        }
    }

    private var contentPreview: String
    {
        switch clip.content
        {
        case .text(let text):
            return text
        case .image:
            return "[图片]"
        case .filePath(let urls):
            return urls.map(\.lastPathComponent).joined(separator: ", ")
        }
    }

    private var timeAgo: String
    {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: clip.timestamp, relativeTo: Date())
    }
}
