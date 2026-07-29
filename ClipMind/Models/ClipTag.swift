import Foundation

/// 标签唯一标识。
///
/// 系统标签 ID 形如 `system.<contentType.rawValue>`，用户标签 ID 形如 `user.<uuid>`。
/// 稳定持久化，重命名不影响 ID。
struct ClipTagID: RawRepresentable, Codable, Hashable, Comparable, Sendable
{
    let rawValue: String

    /// 系统标签 ID，由 ContentType 派生。
    static func system(_ contentType: ContentType) -> ClipTagID
    {
        ClipTagID(rawValue: "system.\(contentType.rawValue)")
    }

    /// 用户标签 ID，默认生成新 UUID。
    static func user(_ id: UUID = UUID()) -> ClipTagID
    {
        ClipTagID(rawValue: "user.\(id.uuidString.lowercased())")
    }

    static func < (lhs: ClipTagID, rhs: ClipTagID) -> Bool
    {
        lhs.rawValue < rhs.rawValue
    }
}

/// 标签来源。
enum ClipTagSource: String, Codable, Equatable, Sendable
{
    case system
    case user
}

/// 标签颜色枚举。
///
/// 与 `SystemTagCatalog` 的 11 个系统标签一一对应，用户标签从中选择。
enum ClipTagColor: String, Codable, CaseIterable, Equatable, Sendable
{
    case violet
    case cyan
    case rose
    case blue
    case amber
    case emerald
    case purple
    case orange
    case teal
    case slate
    case gray
}

/// 标签值类型。
///
/// 名称可变（用户标签重命名），ID、颜色和来源不变。
struct ClipTag: Identifiable, Codable, Equatable, Sendable
{
    let id: ClipTagID
    var name: String
    let color: ClipTagColor
    let source: ClipTagSource
}
