import SwiftUI

/// 标签颜色的 SwiftUI 映射与中文名称。
///
/// 作为标签视觉的唯一来源，避免 `TypeTagView` 与新标签 pill 出现两套颜色表。
/// 颜色值与设计规范 10.3 节一致。
extension ClipTagColor
{
    /// 中文显示名称，用于辅助功能 label 与颜色选择器。
    var displayName: String
    {
        switch self
        {
        case .violet: return "紫罗兰"
        case .cyan: return "青色"
        case .rose: return "玫红"
        case .blue: return "蓝色"
        case .amber: return "琥珀"
        case .emerald: return "翡翠"
        case .purple: return "紫色"
        case .orange: return "橙色"
        case .teal: return "青绿"
        case .slate: return "石板灰"
        case .gray: return "灰色"
        }
    }

    /// SwiftUI 颜色 token，统一标签 pill 的背景与文字色。
    var swiftUIColor: Color
    {
        switch self
        {
        case .violet: return Color(red: 0x8B / 255, green: 0x5C / 255, blue: 0xF6 / 255)
        case .cyan: return Color(red: 0x22 / 255, green: 0xD3 / 255, blue: 0xEE / 255)
        case .rose: return Color(red: 0xF4 / 255, green: 0x3F / 255, blue: 0x5E / 255)
        case .blue: return Color(red: 0x3B / 255, green: 0x82 / 255, blue: 0xF6 / 255)
        case .amber: return Color(red: 0xF5 / 255, green: 0x9E / 255, blue: 0x0B / 255)
        case .emerald: return Color(red: 0x10 / 255, green: 0xB9 / 255, blue: 0x81 / 255)
        case .purple: return Color(red: 0xA8 / 255, green: 0x55 / 255, blue: 0xF7 / 255)
        case .orange: return Color(red: 0xF9 / 255, green: 0x73 / 255, blue: 0x16 / 255)
        case .teal: return Color(red: 0x14 / 255, green: 0xB8 / 255, blue: 0xA6 / 255)
        case .slate: return Color(red: 0x64 / 255, green: 0x74 / 255, blue: 0x8B / 255)
        case .gray: return Color(red: 0x6B / 255, green: 0x72 / 255, blue: 0x80 / 255)
        }
    }
}

/// 统一标签 pill 视觉。
///
/// 在菜单栏、主窗口和快捷粘贴面板复用同一标签样式：低透明度圆角背景 +
/// 颜色文字。`isInteractive` 为 `true` 时启用 hover 反馈，用于标签条内可点击 pill；
/// 为 `false` 时仅作静态展示（如 `TypeTagView` 兼容包装）。
///
/// 辅助功能 label 为「名称，自动分类标签/用户标签，颜色名」，
/// 单行显示、最大宽度 96pt、尾部截断，长名称不扩大命中区或挤掉主内容。
struct TagPillView: View
{
    /// 要展示的标签。
    let tag: ClipTag
    /// 是否处于可点击上下文（标签条内），控制 hover 反馈。
    let isInteractive: Bool

    @State private var isHovered = false

    var body: some View
    {
        Text(tag.name)
            .font(.caption2.weight(.semibold))
            .foregroundColor(tag.color.swiftUIColor)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: 96)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(backgroundColor)
            .cornerRadius(6)
            .accessibilityLabel(accessibilityLabelText)
            .onHover { hovering in
                guard isInteractive else { return }
                isHovered = hovering
            }
    }

    /// pill 背景色：默认低透明度，可交互且 hover 时加深。
    private var backgroundColor: Color
    {
        let opacity = (isInteractive && isHovered) ? 0.32 : 0.2
        return tag.color.swiftUIColor.opacity(opacity)
    }

    /// 辅助功能 label：「名称，来源，颜色名」。
    private var accessibilityLabelText: String
    {
        let sourceText = tag.source == .system ? "自动分类标签" : "用户标签"
        return "\(tag.name)，\(sourceText)，\(tag.color.displayName)"
    }
}
