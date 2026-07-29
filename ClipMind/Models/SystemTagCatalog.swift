import Foundation

/// 系统标签目录。
///
/// 提供 11 个 `ContentType` 到系统标签名称与颜色的唯一映射。
/// 系统标签全局只读，用户标签可全局管理。
enum SystemTagCatalog
{
    /// ContentType 到系统标签的映射。
    private static let mapping: [ContentType: ClipTag] = [
        .code: ClipTag(id: .system(.code), name: "CODE", color: .violet, source: .system),
        .link: ClipTag(id: .system(.link), name: "LINK", color: .cyan, source: .system),
        .error: ClipTag(id: .system(.error), name: "ERROR", color: .rose, source: .system),
        .article: ClipTag(id: .system(.article), name: "ARTICLE", color: .blue, source: .system),
        .todo: ClipTag(id: .system(.todo), name: "TODO", color: .amber, source: .system),
        .meeting: ClipTag(id: .system(.meeting), name: "MEETING", color: .emerald, source: .system),
        .translation: ClipTag(id: .system(.translation), name: "TRANS", color: .purple, source: .system),
        .requirement: ClipTag(id: .system(.requirement), name: "REQ", color: .orange, source: .system),
        .apiDoc: ClipTag(id: .system(.apiDoc), name: "API", color: .teal, source: .system),
        .englishDoc: ClipTag(id: .system(.englishDoc), name: "DOC", color: .slate, source: .system),
        .other: ClipTag(id: .system(.other), name: "OTHER", color: .gray, source: .system)
    ]

    /// 全部系统标签，按 `ContentType.allCases` 顺序构造。
    static let all: [ClipTag] = ContentType.allCases.map { tag(for: $0) }

    /// 返回指定 ContentType 对应的系统标签。
    static func tag(for contentType: ContentType) -> ClipTag
    {
        guard let tag = mapping[contentType]
        else
        {
            fatalError("SystemTagCatalog missing mapping for \(contentType)")
        }
        return tag
    }

    /// 由标签 ID 反查 ContentType，仅接受 `system.` 前缀的 ID。
    static func contentType(for id: ClipTagID) -> ContentType?
    {
        guard id.rawValue.hasPrefix("system.") else { return nil }
        let rawValue = String(id.rawValue.dropFirst("system.".count))
        return ContentType(rawValue: rawValue)
    }
}
