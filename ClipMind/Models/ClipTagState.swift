import Foundation

/// 系统标签处置状态。
///
/// - `pendingMigration`: 旧数据待迁移，迁移时根据 ContentType 关联自身系统标签。
/// - `associated`: 条目当前关联自身系统标签。
/// - `removed`: 用户已移除该条目的系统标签，迁移不恢复。
enum SystemTagDisposition: String, Codable, Equatable, Sendable
{
    case pendingMigration
    case associated
    case removed
}

/// 条目标签状态。
///
/// 记录关联顺序、系统标签处置和迁移版本，随 `ClipItem` 一起加密持久化。
struct ClipTagState: Codable, Equatable, Sendable
{
    /// 当前迁移版本。低于此值的条目需要迁移。
    static let currentMigrationVersion = 1

    /// 关联标签 ID 列表，系统标签在前，用户标签按关联顺序稳定排列。
    var orderedTagIDs: [ClipTagID]

    /// 系统标签处置状态。
    var systemTagDisposition: SystemTagDisposition

    /// 迁移版本号。
    var migrationVersion: Int

    /// 旧数据状态：无关联、待迁移。
    static let legacy = ClipTagState(
        orderedTagIDs: [],
        systemTagDisposition: .pendingMigration,
        migrationVersion: 0
    )

    /// 新条目默认状态：关联自身系统标签。
    static func newItem(contentType: ContentType) -> ClipTagState
    {
        ClipTagState(
            orderedTagIDs: [.system(contentType)],
            systemTagDisposition: .associated,
            migrationVersion: currentMigrationVersion
        )
    }

    /// 是否需要迁移。
    var requiresMigration: Bool
    {
        migrationVersion < Self.currentMigrationVersion
    }
}
