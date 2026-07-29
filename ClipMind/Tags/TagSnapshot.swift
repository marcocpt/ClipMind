import Foundation

/// 标签快照。
///
/// 用户标签目录与条目关联状态的不可变投影，供 UI 消费。
struct TagSnapshot: Equatable, Sendable
{
    /// 用户标签目录。
    var userTags: [ClipTag]

    /// 条目 ID 到标签状态的映射。
    var tagStatesByClipID: [UUID: ClipTagState]

    /// 空快照。
    static let empty = TagSnapshot(userTags: [], tagStatesByClipID: [:])

    /// 全部标签（系统 + 用户）。
    var allTags: [ClipTag]
    {
        SystemTagCatalog.all + userTags
    }

    /// 返回指定条目关联的标签列表。
    func tags(for clipID: UUID) -> [ClipTag]
    {
        // 使用 uniquingKeysWith 防止重复键导致崩溃。
        // 正常情况下 allTags 不应有重复 ID，但 UITEST 夹具注入路径可能
        // 在数据库未完全清理时产生重复，此处防御性处理。
        let tagsByID = Dictionary(
            allTags.map { ($0.id, $0) },
            uniquingKeysWith: { _, new in new }
        )
        return tagStatesByClipID[clipID, default: .legacy].orderedTagIDs.compactMap
        {
            tagsByID[$0]
        }
    }
}
