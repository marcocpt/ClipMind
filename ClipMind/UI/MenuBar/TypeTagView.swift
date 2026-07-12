import SwiftUI

/// 类型标签视图。
///
/// 根据 ContentType 显示对应的彩色标签（CODE/LINK/ERROR 等），
/// 用于 popover 和主窗口中剪贴条目的类型可视化。
/// 颜色规范见设计规范 10.3 节。
struct TypeTagView: View {
    let contentType: ContentType

    var body: some View {
        Text(displayText)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(backgroundColor)
            .cornerRadius(6)
            .accessibilityIdentifier("typeTag_\(contentType.rawValue)")
    }

    /// 标签显示文本（大写缩写，≤ 7 字符以保持宽度一致）
    private var displayText: String {
        switch contentType {
        case .code: return "CODE"
        case .link: return "LINK"
        case .error: return "ERROR"
        case .article: return "ARTICLE"
        case .todo: return "TODO"
        case .meeting: return "MEETING"
        case .translation: return "TRANS"
        case .requirement: return "REQ"
        case .apiDoc: return "API"
        case .englishDoc: return "DOC"
        case .other: return "OTHER"
        }
    }

    /// 标签背景色（对应设计规范 10.3 节类型标签颜色）
    private var backgroundColor: Color {
        switch contentType {
        case .code: return TypeTagColor.violet
        case .link: return TypeTagColor.cyan
        case .error: return TypeTagColor.rose
        case .article: return TypeTagColor.blue
        case .todo: return TypeTagColor.amber
        case .meeting: return TypeTagColor.emerald
        case .translation: return TypeTagColor.purple
        case .requirement: return TypeTagColor.orange
        case .apiDoc: return TypeTagColor.teal
        case .englishDoc: return TypeTagColor.slate
        case .other: return TypeTagColor.gray
        }
    }
}

/// 类型标签颜色定义（对应设计规范 10.3 节）。
private enum TypeTagColor {
    static let violet = Color(red: 0x8B / 255, green: 0x5C / 255, blue: 0xF6 / 255)
    static let cyan = Color(red: 0x22 / 255, green: 0xD3 / 255, blue: 0xEE / 255)
    static let rose = Color(red: 0xF4 / 255, green: 0x3F / 255, blue: 0x5E / 255)
    static let blue = Color(red: 0x3B / 255, green: 0x82 / 255, blue: 0xF6 / 255)
    static let amber = Color(red: 0xF5 / 255, green: 0x9E / 255, blue: 0x0B / 255)
    static let emerald = Color(red: 0x10 / 255, green: 0xB9 / 255, blue: 0x81 / 255)
    static let purple = Color(red: 0xA8 / 255, green: 0x55 / 255, blue: 0xF7 / 255)
    static let orange = Color(red: 0xF9 / 255, green: 0x73 / 255, blue: 0x16 / 255)
    static let teal = Color(red: 0x14 / 255, green: 0xB8 / 255, blue: 0xA6 / 255)
    static let slate = Color(red: 0x64 / 255, green: 0x74 / 255, blue: 0x8B / 255)
    static let gray = Color(red: 0x6B / 255, green: 0x72 / 255, blue: 0x80 / 255)
}
