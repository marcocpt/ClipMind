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
        let tagsByID = Dictionary(uniqueKeysWithValues: allTags.map { ($0.id, $0) })
        return tagStatesByClipID[clipID, default: .legacy].orderedTagIDs.compactMap
        {
            tagsByID[$0]
        }
    }
}
