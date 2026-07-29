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

    /// 标签触发回调（F1.14 标签条点击时触发，与单击/双击主动作隔离）。
    var onTagActivate: (() -> Void)?

    /// 共享标签状态。为 nil 时不显示标签条（任务 5 装配后所有入口都传入同一实例）。
    var tagStore: TagStore?

    var body: some View
    {
        VStack(alignment: .leading, spacing: 6)
        {
            HStack(spacing: 8)
            {
                TypeTagView(contentType: clip.contentType)
                Spacer()
            }
            // 标签条作为独立命中区，与内容主动作隔离。
            // 通过 TagStripContainer 用 @ObservedObject 观察 TagStore，
            // 确保 snapshot 变化时标签条刷新（即使父视图未重新评估 body）。
            if let tagStore = tagStore
            {
                TagStripContainer(
                    tagStore: tagStore,
                    clipID: clip.id,
                    contentType: clip.contentType,
                    onTagActivate: { onTagActivate?() }
                )
            }
            // 内容区域：预览文本 + 来源/时间。
            VStack(alignment: .leading, spacing: 6)
            {
                Text(contentPreview)
                    .font(.system(size: 13))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
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
        }
        .padding(12)
        .background(backgroundColor)
        .overlay(borderOverlay)
        .cornerRadius(12)
        .contentShape(Rectangle())
        .onTapGesture(count: 2)
        {
            onDoubleClick?()
        }
        .onTapGesture(count: 1)
        {
            onSingleClick?()
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

/// 标签条容器：用 `@ObservedObject` 观察 `TagStore`，确保 `snapshot` 变化时
/// `tags(for:)` 被重新调用，标签条和 picker 反映最新状态。
///
/// 独立于父视图的 diffing：即使 `ClipRowView` 的其他属性未变，`TagStore` 的
/// `objectWillChange` 也会触发本视图 `body` 重新评估。这对菜单栏弹窗预览
/// （通过 `UnifiedPastePanelViewModel.tagRevision` 间接观察）尤其重要。
struct TagStripContainer: View
{
    @ObservedObject var tagStore: TagStore
    let clipID: UUID
    let contentType: ContentType
    let onTagActivate: () -> Void

    @State private var isTagPickerPresented = false

    var body: some View
    {
        ClipTagStripView(
            clipID: clipID,
            tags: tagStore.tags(for: clipID),
            onActivate:
            {
                onTagActivate()
                isTagPickerPresented = true
            }
        )
        .popover(isPresented: $isTagPickerPresented, arrowEdge: .bottom)
        {
            TagPickerView(
                clipID: clipID,
                contentType: contentType,
                store: tagStore
            )
        }
    }
}
