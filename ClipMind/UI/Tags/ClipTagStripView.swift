import SwiftUI

/// 标签条视图。
///
/// 在剪贴条目行中展示该条目的全部标签 pill。无标签时显示「+」按钮触发标签选择菜单；
/// 有标签时以 `HStack` 展示最多 5 个 pill，点击任一 pill 触发 `onActivate`。
///
/// 标签主动作与条目主动作隔离：标签条作为独立命中区，点击 pill 只调用 `onActivate`，
/// 不传播到条目的单击/双击回调。单个 pill 文字单行、最大宽度 96pt、尾部截断，
/// 长名称不扩大命中区或挤掉主内容。
///
/// 不使用 `ScrollView(.horizontal)`：嵌套 ScrollView（外层条目列表 + 内层标签条）
/// 会导致 XCUITest 无法计算命中点。最多 5 个 pill 在固定行宽内截断即可。
struct ClipTagStripView: View
{
    /// 标签所属剪贴条目 ID，用于辅助功能 identifier。
    let clipID: UUID
    /// 要展示的标签列表（由数据层保证每条目最多 5 个）。
    let tags: [ClipTag]
    /// 点击 pill 或「+」按钮时触发，由调用方展示标签选择菜单。
    let onActivate: () -> Void

    var body: some View
    {
        HStack(spacing: 6)
        {
            if tags.isEmpty
            {
                Button(action: onActivate)
                {
                    Image(systemName: "plus")
                        .frame(minWidth: 22, minHeight: 22)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("添加标签")
                .accessibilityIdentifier("tagAdd_\(clipID.uuidString)")
            } else {
                HStack(spacing: 6)
                {
                    ForEach(tags)
                    { tag in
                        Button(action: onActivate)
                        {
                            TagPillView(tag: tag, isInteractive: true)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier(
                            "clipTag_\(clipID.uuidString)_\(tag.id.rawValue)"
                        )
                    }
                }
            }
        }
    }
}
