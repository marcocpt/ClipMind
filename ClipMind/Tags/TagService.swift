import Foundation

/// 标签服务端口。
protocol TagServicing: AnyObject
{
    func snapshot() async throws -> TagSnapshot
    func createAndAttach(name: String, color: ClipTagColor, clipID: UUID) async throws -> TagSnapshot
    func setAttached(_ isAttached: Bool, tagID: ClipTagID, clipID: UUID) async throws -> TagSnapshot
    func renameUserTag(id: ClipTagID, name: String) async throws -> TagSnapshot
    func deleteUserTag(id: ClipTagID) async throws -> TagSnapshot
    func migrateNextBatch(limit: Int) async throws -> TagMigrationBatchResult
}

/// 唯一业务规则边界。
///
/// 每个方法按"读取最新快照 → 业务校验 → 单次 repository mutation → 重新读取快照 → 固定 metadata 日志"执行。
/// 名称校验调用 `TagNameValidator.validate`，不在其他地方手写第二份 trim/重名规则。
actor TagService: TagServicing
{
    static let maximumTagsPerClip = 5

    private let repository: TagRepository
    private let logger: TagOperationLogging

    init(repository: TagRepository, logger: TagOperationLogging)
    {
        self.repository = repository
        self.logger = logger
    }

    func snapshot() async throws -> TagSnapshot
    {
        do
        {
            return try repository.loadSnapshot()
        } catch {
            logger.record(operation: .migrate, result: .failure, error: .persistenceFailed, count: 0)
            throw TagError.persistenceFailed
        }
    }

    func createAndAttach(
        name: String,
        color: ClipTagColor,
        clipID: UUID
    ) async throws -> TagSnapshot
    {
        do
        {
            let snapshot = try repository.loadSnapshot()

            // 名称校验
            let trimmedName = try TagNameValidator.validate(
                candidate: name,
                existingTags: snapshot.allTags
            )

            // 检查条目是否存在
            guard snapshot.tagStatesByClipID[clipID] != nil else
            {
                logger.record(operation: .create, result: .failure, error: .clipNotFound, count: 0)
                throw TagError.clipNotFound
            }

            // 检查标签上限
            let currentState = snapshot.tagStatesByClipID[clipID, default: .legacy]
            if currentState.orderedTagIDs.count >= Self.maximumTagsPerClip
            {
                logger.record(operation: .create, result: .failure, error: .tagLimitReached, count: 0)
                throw TagError.tagLimitReached
            }

            let tag = ClipTag(id: .user(), name: trimmedName, color: color, source: .user)
            try repository.apply(.createAndAttach(tag: tag, clipID: clipID))
            logger.record(operation: .create, result: .success, error: nil, count: 1)

            return try repository.loadSnapshot()
        } catch let error as TagError {
            logger.record(operation: .create, result: .failure, error: error, count: 0)
            throw error
        } catch {
            logger.record(operation: .create, result: .failure, error: .persistenceFailed, count: 0)
            throw TagError.persistenceFailed
        }
    }

    func setAttached(
        _ isAttached: Bool,
        tagID: ClipTagID,
        clipID: UUID
    ) async throws -> TagSnapshot
    {
        let operation: TagOperation = isAttached ? .attach : .detach
        do
        {
            let snapshot = try repository.loadSnapshot()

            // 检查条目是否存在
            guard let currentState = snapshot.tagStatesByClipID[clipID] else
            {
                logger.record(operation: operation, result: .failure, error: .clipNotFound, count: 0)
                throw TagError.clipNotFound
            }

            if isAttached
            {
                try validateAttach(
                    tagID: tagID,
                    clipID: clipID,
                    currentState: currentState,
                    snapshot: snapshot
                )
                try repository.apply(.attach(tagID: tagID, clipID: clipID))
            } else {
                try validateDetach(tagID: tagID, clipID: clipID, snapshot: snapshot)
                try repository.apply(.detach(tagID: tagID, clipID: clipID))
            }

            logger.record(operation: operation, result: .success, error: nil, count: 1)
            return try repository.loadSnapshot()
        } catch let error as TagError {
            logger.record(operation: operation, result: .failure, error: error, count: 0)
            throw error
        } catch {
            logger.record(operation: operation, result: .failure, error: .persistenceFailed, count: 0)
            throw TagError.persistenceFailed
        }
    }

    // MARK: - Attach / Detach 校验

    private func validateAttach(
        tagID: ClipTagID,
        clipID: UUID,
        currentState: ClipTagState,
        snapshot: TagSnapshot
    ) throws
    {
        if let contentType = SystemTagCatalog.contentType(for: tagID)
        {
            // 系统标签必须匹配条目 contentType
            let clipContentType = currentContentType(for: clipID, in: snapshot)
            if clipContentType != contentType
            {
                logger.record(operation: .attach, result: .failure, error: .systemTagNotEligible, count: 0)
                throw TagError.systemTagNotEligible
            }
        } else {
            // 用户标签必须存在于目录
            guard snapshot.userTags.contains(where: { $0.id == tagID }) else
            {
                logger.record(operation: .attach, result: .failure, error: .tagNotFound, count: 0)
                throw TagError.tagNotFound
            }
        }

        // 检查标签上限（如果是新增关联）
        if !currentState.orderedTagIDs.contains(tagID),
           currentState.orderedTagIDs.count >= Self.maximumTagsPerClip
        {
            logger.record(operation: .attach, result: .failure, error: .tagLimitReached, count: 0)
            throw TagError.tagLimitReached
        }
    }

    private func validateDetach(
        tagID: ClipTagID,
        clipID: UUID,
        snapshot: TagSnapshot
    ) throws
    {
        // 系统标签只能移除自身的
        if let contentType = SystemTagCatalog.contentType(for: tagID)
        {
            let clipContentType = currentContentType(for: clipID, in: snapshot)
            if clipContentType != contentType
            {
                logger.record(operation: .detach, result: .failure, error: .systemTagNotEligible, count: 0)
                throw TagError.systemTagNotEligible
            }
        }
    }

    func renameUserTag(id: ClipTagID, name: String) async throws -> TagSnapshot
    {
        do
        {
            // 系统标签只读
            if SystemTagCatalog.contentType(for: id) != nil
            {
                logger.record(operation: .rename, result: .failure, error: .systemTagReadOnly, count: 0)
                throw TagError.systemTagReadOnly
            }

            let snapshot = try repository.loadSnapshot()

            // 标签必须存在
            guard snapshot.userTags.contains(where: { $0.id == id }) else
            {
                logger.record(operation: .rename, result: .failure, error: .tagNotFound, count: 0)
                throw TagError.tagNotFound
            }

            // 名称校验（排除自身）
            let trimmedName = try TagNameValidator.validate(
                candidate: name,
                existingTags: snapshot.allTags,
                excluding: id
            )

            try repository.apply(.rename(tagID: id, name: trimmedName))
            logger.record(operation: .rename, result: .success, error: nil, count: 1)

            return try repository.loadSnapshot()
        } catch let error as TagError {
            logger.record(operation: .rename, result: .failure, error: error, count: 0)
            throw error
        } catch {
            logger.record(operation: .rename, result: .failure, error: .persistenceFailed, count: 0)
            throw TagError.persistenceFailed
        }
    }

    func deleteUserTag(id: ClipTagID) async throws -> TagSnapshot
    {
        do
        {
            // 系统标签只读
            if SystemTagCatalog.contentType(for: id) != nil
            {
                logger.record(operation: .delete, result: .failure, error: .systemTagReadOnly, count: 0)
                throw TagError.systemTagReadOnly
            }

            let snapshot = try repository.loadSnapshot()

            // 标签必须存在
            guard snapshot.userTags.contains(where: { $0.id == id }) else
            {
                logger.record(operation: .delete, result: .failure, error: .tagNotFound, count: 0)
                throw TagError.tagNotFound
            }

            try repository.apply(.delete(tagID: id))
            logger.record(operation: .delete, result: .success, error: nil, count: 1)

            return try repository.loadSnapshot()
        } catch let error as TagError {
            logger.record(operation: .delete, result: .failure, error: error, count: 0)
            throw error
        } catch {
            logger.record(operation: .delete, result: .failure, error: .persistenceFailed, count: 0)
            throw TagError.persistenceFailed
        }
    }

    func migrateNextBatch(limit: Int) async throws -> TagMigrationBatchResult
    {
        do
        {
            let result = try repository.migrateNextBatch(limit: limit)
            logger.record(operation: .migrate, result: .success, error: nil, count: result.migratedCount)
            return result
        } catch {
            logger.record(operation: .migrate, result: .failure, error: .persistenceFailed, count: 0)
            throw TagError.persistenceFailed
        }
    }

    // MARK: - 辅助

    /// 从 snapshot 推断条目的 contentType。
    ///
    /// 通过 systemTagDisposition 和 orderedTagIDs 中的系统标签推断。
    private func currentContentType(for clipID: UUID, in snapshot: TagSnapshot) -> ContentType?
    {
        let state = snapshot.tagStatesByClipID[clipID, default: .legacy]
        if state.systemTagDisposition == .associated
        {
            for tagID in state.orderedTagIDs
            {
                if let contentType = SystemTagCatalog.contentType(for: tagID)
                {
                    return contentType
                }
            }
        }
        return nil
    }
}

// MARK: - 不可用标签服务

/// 当标签后端初始化失败时使用，所有操作抛出 `.persistenceFailed`。
final class UnavailableTagService: TagServicing
{
    func snapshot() async throws -> TagSnapshot
    {
        throw TagError.persistenceFailed
    }

    func createAndAttach(name: String, color: ClipTagColor, clipID: UUID) async throws -> TagSnapshot
    {
        throw TagError.persistenceFailed
    }

    func setAttached(_ isAttached: Bool, tagID: ClipTagID, clipID: UUID) async throws -> TagSnapshot
    {
        throw TagError.persistenceFailed
    }

    func renameUserTag(id: ClipTagID, name: String) async throws -> TagSnapshot
    {
        throw TagError.persistenceFailed
    }

    func deleteUserTag(id: ClipTagID) async throws -> TagSnapshot
    {
        throw TagError.persistenceFailed
    }

    func migrateNextBatch(limit: Int) async throws -> TagMigrationBatchResult
    {
        throw TagError.persistenceFailed
    }
}
