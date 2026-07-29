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
            // tap gesture 仅覆盖内容区域，不覆盖标签条，避免拦截标签 pill 的 tap。
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
            .frame(maxWidth: .infinity, alignment: .leading)
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
        .padding(12)
        .background(backgroundColor)
        .overlay(borderOverlay)
        .cornerRadius(12)
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
///
/// F1.14：picker 呈现由 `TagPickerPresenter` 单例管理（基于 `NSPanel`），
/// 不再使用 SwiftUI `.popover()` 或 `NSPopover`。原因：
/// 1. `.popover()` 在手动创建的 `NSHostingController + NSWindow` 中无法可靠工作
///    （macOS 13 限制）。
/// 2. `NSPopover` 内容窗口对 XCUITest 不可见（accessibility 元素查询超时）。
/// `NSPanel` 作为常规窗口出现在 accessibility 树中，三个入口行为一致。
struct TagStripContainer: View
{
    @ObservedObject var tagStore: TagStore
    let clipID: UUID
    let contentType: ContentType
    let onTagActivate: () -> Void

    /// 锚点 NSView 持有者（引用语义）。
    ///
    /// 用 `@State` + class 而非 `@State` + NSView? 的原因：`onActivate` 与
    /// `onAnchorReady` 是两个独立闭包，分别捕获 `self`（struct 值类型）。SwiftUI
    /// 重建 view 时新 struct 的 `@State` storage 与旧 struct 的 storage 是否共享
    /// 取决于 view 身份稳定性，在 `LazyVStack` + `ForEach` 场景下不可靠。
    /// 改用 class holder 后，两个闭包捕获同一引用，写入对读取立即可见。
    @State private var anchorHolder = AnchorHolder()

    var body: some View
    {
        ClipTagStripView(
            clipID: clipID,
            tags: tagStore.tags(for: clipID),
            onActivate:
            {
                NSLog("[DIAG] TagStrip onActivate: called, anchorHolder.view=\(String(describing: anchorHolder.view))")
                onTagActivate()
                let anchor = anchorHolder.view
                TagPickerPresenter.shared.show(
                    clipID: clipID,
                    contentType: contentType,
                    store: tagStore,
                    relativeTo: anchor
                )
            }
        )
        .background(
            TagPickerAnchor { view in
                anchorHolder.view = view
            }
        )
    }
}

/// 锚点 NSView 引用持有者（引用语义，确保跨闭包共享）。
final class AnchorHolder
{
    var view: NSView?
}
