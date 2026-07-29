import Foundation

/// 标签存储端口。
///
/// 定义加载快照、应用原子 mutation 和批量迁移的接口。
protocol TagRepository: AnyObject
{
    /// 加载当前标签快照。
    func loadSnapshot() throws -> TagSnapshot

    /// 应用单个标签 mutation（原子事务）。
    func apply(_ mutation: TagMutation) throws

    /// 迁移下一批旧数据条目。
    func migrateNextBatch(limit: Int) throws -> TagMigrationBatchResult
}

/// 标签 mutation 值类型。
enum TagMutation: Equatable
{
    case createAndAttach(tag: ClipTag, clipID: UUID)
    case attach(tagID: ClipTagID, clipID: UUID)
    case detach(tagID: ClipTagID, clipID: UUID)
    case rename(tagID: ClipTagID, name: String)
    case delete(tagID: ClipTagID)
}

/// 迁移批次结果。
struct TagMigrationBatchResult: Equatable
{
    let migratedCount: Int
    let remainingCount: Int
}
