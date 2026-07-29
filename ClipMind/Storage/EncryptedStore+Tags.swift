import Foundation
import SQLite

/// 标签存储 schema：key-value 加密 blob 表。
enum TagStorageSchema
{
    static let catalog = Table("tag_catalog")
    static let key = Expression<String>("key")
    static let valueBlob = Expression<Data>("value_blob")
    static let catalogKey = "user-tags"
}

/// 持久化的用户标签目录。
private struct PersistedTagCatalog: Codable, Equatable
{
    var userTags: [ClipTag]
}

// MARK: - EncryptedStore + TagRepository

extension EncryptedStore: TagRepository
{
    func loadSnapshot() throws -> TagSnapshot
    {
        let userTags = try loadUserTags()
        let tagStatesByClipID = try loadTagStatesByClipID()
        return TagSnapshot(
            userTags: userTags,
            tagStatesByClipID: tagStatesByClipID
        )
    }

    func apply(_ mutation: TagMutation) throws
    {
        try database.transaction
        {
            switch mutation
            {
            case let .createAndAttach(tag, clipID):
                try applyCreateAndAttach(tag: tag, clipID: clipID)
            case let .attach(tagID, clipID):
                try applyAttach(tagID: tagID, clipID: clipID)
            case let .detach(tagID, clipID):
                try applyDetach(tagID: tagID, clipID: clipID)
            case let .rename(tagID, name):
                try applyRename(tagID: tagID, name: name)
            case let .delete(tagID):
                try applyDelete(tagID: tagID)
            }
        }
    }

    func migrateNextBatch(limit: Int) throws -> TagMigrationBatchResult
    {
        var migratedCount = 0
        var remainingCount = 0

        // 查询所有条目，按 id 排序保证稳定批次
        let query = clips
            .select(idColumn, contentBlob)
            .order(idColumn.asc)

        var batchUpdates: [(UUID, ClipTagState)] = []

        for row in try database.prepare(query)
        {
            let encrypted = row[contentBlob]
            let json = try decrypt(encrypted)
            var item = try decodeJSON(ClipItem.self, from: json)

            if !item.tagState.requiresMigration
            {
                continue
            }

            // 需要迁移但本批已满，计入剩余
            if batchUpdates.count >= limit
            {
                remainingCount += 1
                continue
            }

            // 迁移：根据 contentType 关联自身系统标签
            // pendingMigration → associated；removed 保持无系统关联
            let disposition = item.tagState.systemTagDisposition
            switch disposition
            {
            case .pendingMigration:
                item.tagState = ClipTagState.newItem(contentType: item.contentType)
            case .removed:
                item.tagState.migrationVersion = ClipTagState.currentMigrationVersion
                item.tagState.orderedTagIDs.removeAll { tagID in
                    SystemTagCatalog.contentType(for: tagID) != nil
                }
            case .associated:
                item.tagState.migrationVersion = ClipTagState.currentMigrationVersion
            }

            batchUpdates.append((item.id, item.tagState))
            migratedCount += 1
        }

        // 批量写入
        try database.transaction
        {
            for (clipID, tagState) in batchUpdates
            {
                try persistTagState(tagState, for: clipID)
            }
        }

        return TagMigrationBatchResult(
            migratedCount: migratedCount,
            remainingCount: remainingCount
        )
    }

    // MARK: - Mutation 实现

    private func applyCreateAndAttach(tag: ClipTag, clipID: UUID) throws
    {
        // 1. 添加到用户标签目录（去重：如果已存在同 ID 的标签，跳过追加）
        var catalog = try loadPersistedCatalog()
        if !catalog.userTags.contains(where: { $0.id == tag.id })
        {
            catalog.userTags.append(tag)
            try savePersistedCatalog(catalog)
        }

        // 2. 关联到条目
        try attachTagToClip(tagID: tag.id, clipID: clipID)
    }

    private func applyAttach(tagID: ClipTagID, clipID: UUID) throws
    {
        try attachTagToClip(tagID: tagID, clipID: clipID)
    }

    private func applyDetach(tagID: ClipTagID, clipID: UUID) throws
    {
        guard var item = try loadClip(id: clipID) else { return }

        item.tagState.orderedTagIDs.removeAll { $0 == tagID }

        // 如果是系统标签，更新 disposition
        if let contentType = SystemTagCatalog.contentType(for: tagID),
           contentType == item.contentType
        {
            item.tagState.systemTagDisposition = .removed
        }

        try persistFullClip(item)
    }

    private func applyRename(tagID: ClipTagID, name: String) throws
    {
        var catalog = try loadPersistedCatalog()
        guard let index = catalog.userTags.firstIndex(where: { $0.id == tagID }) else
        {
            return
        }
        catalog.userTags[index].name = name
        try savePersistedCatalog(catalog)
    }

    private func applyDelete(tagID: ClipTagID) throws
    {
        // 1. 从目录删除
        var catalog = try loadPersistedCatalog()
        catalog.userTags.removeAll { $0.id == tagID }
        try savePersistedCatalog(catalog)

        // 2. 从所有条目中移除该标签关联
        let query = clips.select(idColumn, contentBlob)
        for row in try database.prepare(query)
        {
            let encrypted = row[contentBlob]
            let json = try decrypt(encrypted)
            var item = try decodeJSON(ClipItem.self, from: json)

            if item.tagState.orderedTagIDs.contains(tagID)
            {
                item.tagState.orderedTagIDs.removeAll { $0 == tagID }
                try persistFullClip(item)
            }
        }
    }

    // MARK: - 辅助

    private func attachTagToClip(tagID: ClipTagID, clipID: UUID) throws
    {
        guard var item = try loadClip(id: clipID) else { return }

        // 去重
        if item.tagState.orderedTagIDs.contains(tagID) { return }

        // 如果是系统标签且匹配条目 contentType，恢复 associated
        if let contentType = SystemTagCatalog.contentType(for: tagID),
           contentType == item.contentType
        {
            item.tagState.systemTagDisposition = .associated
            // 系统标签放在第一位
            item.tagState.orderedTagIDs.removeAll { $0 == tagID }
            item.tagState.orderedTagIDs.insert(tagID, at: 0)
        } else {
            // 用户标签追加到末尾
            item.tagState.orderedTagIDs.append(tagID)
        }

        // 确保系统标签（associated 状态）在用户标签之前
        item.tagState.orderedTagIDs = reorderTagIDs(
            orderedTagIDs: item.tagState.orderedTagIDs,
            contentType: item.contentType,
            disposition: item.tagState.systemTagDisposition
        )

        try persistFullClip(item)
    }

    private func reorderTagIDs(
        orderedTagIDs: [ClipTagID],
        contentType: ContentType,
        disposition: SystemTagDisposition
    ) -> [ClipTagID]
    {
        let systemTagID = ClipTagID.system(contentType)
        var systemIDs: [ClipTagID] = []
        var userIDs: [ClipTagID] = []

        for tagID in orderedTagIDs
        {
            if SystemTagCatalog.contentType(for: tagID) != nil
            {
                if !systemIDs.contains(tagID)
                {
                    systemIDs.append(tagID)
                }
            } else {
                if !userIDs.contains(tagID)
                {
                    userIDs.append(tagID)
                }
            }
        }

        // 如果 disposition 是 associated 且系统标签不在列表中，添加到开头
        if disposition == .associated, !systemIDs.contains(systemTagID)
        {
            systemIDs.insert(systemTagID, at: 0)
        }

        return systemIDs + userIDs
    }

    // MARK: - 持久化辅助

    private func loadUserTags() throws -> [ClipTag]
    {
        try loadPersistedCatalog().userTags
    }

    private func loadPersistedCatalog() throws -> PersistedTagCatalog
    {
        let query = TagStorageSchema.catalog
            .select(TagStorageSchema.valueBlob)
            .filter(TagStorageSchema.key == TagStorageSchema.catalogKey)
            .limit(1)

        for row in try database.prepare(query)
        {
            let encrypted = row[TagStorageSchema.valueBlob]
            let json = try decrypt(encrypted)
            return try decodeJSON(PersistedTagCatalog.self, from: json)
        }

        return PersistedTagCatalog(userTags: [])
    }

    private func savePersistedCatalog(_ catalog: PersistedTagCatalog) throws
    {
        let json = try encodeJSON(catalog)
        let encrypted = try encrypt(json)

        let row = TagStorageSchema.catalog
            .filter(TagStorageSchema.key == TagStorageSchema.catalogKey)

        let existing = try database.scalar(row.count)
        if existing > 0
        {
            try database.run(
                row.update(TagStorageSchema.valueBlob <- encrypted)
            )
        } else {
            try database.run(
                TagStorageSchema.catalog.insert(
                    TagStorageSchema.key <- TagStorageSchema.catalogKey,
                    TagStorageSchema.valueBlob <- encrypted
                )
            )
        }
    }

    private func loadTagStatesByClipID() throws -> [UUID: ClipTagState]
    {
        var result: [UUID: ClipTagState] = [:]
        let query = clips.select(idColumn, contentBlob)

        for row in try database.prepare(query)
        {
            let id = UUID(uuidString: row[idColumn]) ?? UUID()
            let encrypted = row[contentBlob]
            let json = try decrypt(encrypted)
            let item = try decodeJSON(ClipItem.self, from: json)
            result[id] = item.tagState
        }

        return result
    }

    /// 仅更新单个 ClipItem 的 tagState（保留其他字段）。
    private func persistTagState(_ tagState: ClipTagState, for clipID: UUID) throws
    {
        guard var item = try loadClip(id: clipID) else { return }
        item.tagState = tagState
        try persistFullClip(item)
    }

    /// 完整覆写 ClipItem（用于标签 mutation 中的条目更新）。
    private func persistFullClip(_ item: ClipItem) throws
    {
        let json = try encodeJSON(item)
        let encryptedContent = try encrypt(json)

        let embeddingsData: Data?
        if let embeddings = item.embeddings, !embeddings.isEmpty
        {
            let embJson = try encodeJSON(embeddings)
            embeddingsData = try encrypt(embJson)
        } else {
            embeddingsData = nil
        }

        let row = clips.filter(idColumn == item.id.uuidString)
        try database.run(
            row.update(
                contentBlob <- encryptedContent,
                contentTypeColumn <- item.contentType.rawValue,
                sourceAppColumn <- item.sourceApp,
                embeddingsBlob <- embeddingsData,
                isSampleColumn <- item.isSample
            )
        )
    }
}
