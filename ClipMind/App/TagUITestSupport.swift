#if CLIPMIND_DEV
import AppKit
import Foundation

/// F1.14 UI 测试支持：仅在 `CLIPMIND_DEV` 编译条件下可用。
///
/// 提供标签 UI 测试的启动参数解析、隔离数据库夹具注入和 `FailOnceTagRepository` 包装。
/// 生产构建（主 Scheme `ClipMind`）不包含此文件，确保测试基础设施不泄漏到发布构建。
///
/// - `--UITEST_TAG_FIXTURE`：为 `previewClips[0]` 创建 2 个用户标签，验证有标签条。
/// - `--UITEST_TAG_EMPTY_CLIP`：确保 `previewClips[1]` 无任何标签，验证空标签条「+」。
/// - `--UITEST_TAG_LIMIT_FIXTURE`：为 `previewClips[0]` 注入 5 个标签，验证上限。
/// - `--UITEST_TAG_FAIL_ONCE=<operation>`：包装 repository 使指定 operation 第一次失败。
/// - `--UITEST_TAG_MIGRATION_FIXTURE`：创建 100 条 legacy 数据和 1 个 removed disposition 条目。
/// - `--UITEST_TAG_PASTE_PROBE`：启用粘贴探针接收窗口，验证标签点击不触发粘贴。
/// - `--UITEST_UPGRADE_SEED_DEFAULT_PATH`：在 disposable 账号下向旧默认路径写入 upgrade fixture。
enum TagUITestSupport
{
    // MARK: - 启动参数常量

    static let tagFixtureArg = "--UITEST_TAG_FIXTURE"
    static let tagEmptyClipArg = "--UITEST_TAG_EMPTY_CLIP"
    static let tagLimitFixtureArg = "--UITEST_TAG_LIMIT_FIXTURE"
    static let tagFailOnceArg = "--UITEST_TAG_FAIL_ONCE"
    static let tagFilterFixtureArg = ClipTestData.tagFilterFixtureArg
    static let tagMigrationFixtureArg = "--UITEST_TAG_MIGRATION_FIXTURE"
    static let tagPasteProbeArg = "--UITEST_TAG_PASTE_PROBE"
    static let upgradeSeedDefaultPathArg = "--UITEST_UPGRADE_SEED_DEFAULT_PATH"

    // MARK: - 稳定夹具标签 ID

    /// 标准夹具使用的 2 个用户标签稳定 UUID。
    static let standardFixtureTagIDs: [UUID] = [
        UUID(uuidString: "00000000-0000-4000-8000-000000000101")!,
        UUID(uuidString: "00000000-0000-4000-8000-000000000102")!
    ]

    /// 上限夹具使用的 5 个用户标签稳定 UUID。
    static let limitFixtureTagIDs: [UUID] = [
        UUID(uuidString: "00000000-0000-4000-8000-000000000201")!,
        UUID(uuidString: "00000000-0000-4000-8000-000000000202")!,
        UUID(uuidString: "00000000-0000-4000-8000-000000000203")!,
        UUID(uuidString: "00000000-0000-4000-8000-000000000204")!,
        UUID(uuidString: "00000000-0000-4000-8000-000000000205")!
    ]

    /// 上限夹具中未关联到 `previewClips[0]` 的候选标签稳定 UUID。
    ///
    /// 这 2 个标签关联到 `previewClips[1]`，在 `previewClips[0]` 的 picker 中
    /// 显示为未选中候选，满足 `testPicker_Limit_UnselectedDisabled_NoDialog`
    /// 对「满额时应存在未选择的候选」的断言。
    static let limitFixtureUnselectedTagIDs: [UUID] = [
        UUID(uuidString: "00000000-0000-4000-8000-000000000206")!,
        UUID(uuidString: "00000000-0000-4000-8000-000000000207")!
    ]

    // MARK: - 参数解析

    static var shouldSeedTagFixture: Bool
    {
        CommandLine.arguments.contains(tagFixtureArg)
    }

    static var shouldSeedEmptyClip: Bool
    {
        CommandLine.arguments.contains(tagEmptyClipArg)
    }

    static var shouldSeedLimitFixture: Bool
    {
        CommandLine.arguments.contains(tagLimitFixtureArg)
    }

    static var shouldSeedTagFilterFixture: Bool
    {
        CommandLine.arguments.contains(tagFilterFixtureArg)
    }

    /// Phase 5：迁移夹具（100 条 legacy + 1 个 removed disposition）。
    static var shouldSeedMigrationFixture: Bool
    {
        CommandLine.arguments.contains(tagMigrationFixtureArg)
    }

    /// Phase 5：粘贴探针接收窗口。
    static var shouldEnablePasteProbe: Bool
    {
        CommandLine.arguments.contains(tagPasteProbeArg)
    }

    /// Phase 5：向旧默认路径写入 upgrade fixture（仅 disposable 账号）。
    static var shouldSeedUpgradeDefaultPath: Bool
    {
        CommandLine.arguments.contains(upgradeSeedDefaultPathArg)
    }

    /// FailOnce 模式：指定闭集 operation 仅第一次抛 `.persistenceFailed`。
    enum FailOnceOperation: String, CaseIterable
    {
        case create
        case attach
        case detach
        case rename
        case delete
        case migrate
    }

    static var failOnceOperation: FailOnceOperation?
    {
        guard let index = CommandLine.arguments.firstIndex(of: tagFailOnceArg),
              index + 1 < CommandLine.arguments.count
        else
        {
            return nil
        }
        return FailOnceOperation(rawValue: CommandLine.arguments[index + 1])
    }

    // MARK: - Repository 包装

    /// 当 `--UITEST_TAG_FAIL_ONCE` 存在时，包装 base repository 使指定 operation 第一次失败。
    /// 不读取或记录 associated value，生产构建不调用此方法。
    static func wrapRepositoryIfNeeded(_ base: TagRepository) -> TagRepository
    {
        guard let operation = failOnceOperation else
        {
            return base
        }
        return FailOnceTagRepository(wrapping: base, failOperation: operation)
    }

    // MARK: - 夹具注入

    /// 根据启动参数注入标签夹具。在 `tagBackend` 构造后、`tagStore.load()` 前调用。
    ///
    /// 先持久化夹具 ClipItem 到 `EncryptedStore`（确保 tag state 存在），
    /// 再通过 `repository.apply` 注入用户标签关联或移除系统标签。
    static func seedFixturesIfNeeded(store: EncryptedStore, repository: TagRepository)
    {
        guard shouldSeedTagFixture
            || shouldSeedLimitFixture
            || shouldSeedEmptyClip
            || shouldSeedTagFilterFixture
            || shouldSeedMigrationFixture
        else
        {
            return
        }

        // 迁移夹具使用独立的 100 条 legacy ClipItem，不与 previewClips 混用。
        if shouldSeedMigrationFixture
        {
            seedMigrationFixture(store: store, repository: repository)
            return
        }

        // 标签筛选夹具使用独立的 4 条 ClipItem；其他夹具使用 previewClips。
        let clipsToPersist = shouldSeedTagFilterFixture
            ? ClipTestData.tagFilterFixtureClips
            : ClipTestData.previewClips

        // 先持久化夹具 clips，确保 tag state 存在。
        // 使用 update（INSERT OR REPLACE）而非 save（INSERT）：
        // 本地多次运行时 clipmind.db 持久化，save 会因主键冲突失败。
        // update 会保留数据库中已有的 tagState，但后续 repository.apply
        // 会重建标签关联，因此不会影响夹具一致性。
        // CI 每次全新环境，save 和 update 行为一致。
        for clip in clipsToPersist
        {
            do
            {
                try store.update(clip)
            } catch
            {
                LogCategory.app.error("TagUITestSupport update clip failed")
            }
        }

        if shouldSeedTagFilterFixture
        {
            seedTagFilterFixture(repository: repository)
        }
        if shouldSeedLimitFixture
        {
            seedLimitFixture(repository: repository)
        }
        if shouldSeedTagFixture
        {
            seedStandardFixture(repository: repository)
        }
        if shouldSeedEmptyClip
        {
            seedEmptyClipFixture(repository: repository)
        }
    }

    // MARK: - 私有夹具方法

    /// 创建 2 个用户标签（"工作"、"参考"）。
    ///
    /// "工作"关联到 `previewClips[0]`（code 类型），"参考"关联到 `previewClips[1]`（link 类型）。
    /// 这样 `previewClips[0]` 的"参考"标签初始未选择，用于 `testPicker_Toggle_SelectAndDeselect`；
    /// 两个标签都在 userTags 目录中，用于 `testPicker_Search_FiltersCandidates` 等候选列表测试。
    private static func seedStandardFixture(repository: TagRepository)
    {
        let firstClipID = ClipTestData.previewClipIDs[0]
        let secondClipID = ClipTestData.previewClipIDs[1]
        let workTag = ClipTag(
            id: .user(standardFixtureTagIDs[0]),
            name: "工作",
            color: .blue,
            source: .user
        )
        let referenceTag = ClipTag(
            id: .user(standardFixtureTagIDs[1]),
            name: "参考",
            color: .amber,
            source: .user
        )
        do
        {
            try repository.apply(.createAndAttach(tag: workTag, clipID: firstClipID))
            try repository.apply(.createAndAttach(tag: referenceTag, clipID: secondClipID))
        } catch
        {
            LogCategory.app.error("TagUITestSupport seedStandardFixture failed")
        }
    }

    /// 为 `previewClips[0]` 注入 5 个用户标签（上限测试），并向 `previewClips[1]`
    /// 注入 2 个额外用户标签作为未选中候选。
    ///
    /// 同时 detach clip[0] 的系统标签（`system.code`）：previewClips 自带
    /// `tagState: .newItem(contentType:)`，保存后系统标签已关联，5 用户 + 1 系统 = 6，
    /// 释放一个用户标签后仍为 5，`isAtLimit` 不变，上限提示不消失。detach 后
    /// 恰好 5 个已选，释放一个 → 4，提示消失；系统标签仍在候选中（未选中）。
    private static func seedLimitFixture(repository: TagRepository)
    {
        let clipID = ClipTestData.previewClipIDs[0]
        let colors: [ClipTagColor] = [.violet, .cyan, .rose, .blue, .amber]
        for index in 0..<limitFixtureTagIDs.count
        {
            let tag = ClipTag(
                id: .user(limitFixtureTagIDs[index]),
                name: "标签\(index + 1)",
                color: colors[index],
                source: .user
            )
            do
            {
                try repository.apply(.createAndAttach(tag: tag, clipID: clipID))
            } catch
            {
                LogCategory.app.error("TagUITestSupport seedLimitFixture[\(index)] failed")
            }
        }
        // detach 系统标签，使 clip[0] 恰好 5 个已选用户标签，满足上限释放测试。
        do
        {
            try repository.apply(.detach(tagID: .system(.code), clipID: clipID))
        } catch
        {
            LogCategory.app.error("TagUITestSupport seedLimitFixture detach system tag failed")
        }
        // 2 个额外候选标签关联到 clip[1]，在 clip[0] 的 picker 中显示为未选中。
        let unselectedClipID = ClipTestData.previewClipIDs[1]
        let unselectedColors: [ClipTagColor] = [.emerald, .purple]
        for index in 0..<limitFixtureUnselectedTagIDs.count
        {
            let tag = ClipTag(
                id: .user(limitFixtureUnselectedTagIDs[index]),
                name: "候选\(index + 1)",
                color: unselectedColors[index],
                source: .user
            )
            do
            {
                try repository.apply(.createAndAttach(tag: tag, clipID: unselectedClipID))
            } catch
            {
                LogCategory.app.error("TagUITestSupport seedLimitFixture unselected[\(index)] failed")
            }
        }
    }

    /// 移除 `previewClips[1]`（link 类型）的系统标签，验证空标签条「+」。
    private static func seedEmptyClipFixture(repository: TagRepository)
    {
        let clipID = ClipTestData.previewClipIDs[1]
        let systemTagID = ClipTagID.system(.link)
        do
        {
            try repository.apply(.detach(tagID: systemTagID, clipID: clipID))
        } catch
        {
            LogCategory.app.error("TagUITestSupport seedEmptyClipFixture failed")
        }
    }

    /// Phase 3 任务 4：注入标签筛选夹具。
    ///
    /// 创建 2 个用户标签（"重要"、"待处理"），按计划表格关联到 4 条夹具 ClipItem：
    /// - tag-result-1: 重要、待处理
    /// - tag-result-2: 重要
    /// - tag-result-3: 重要、待处理
    /// - tag-result-4: 重要、待处理
    ///
    /// 系统标签（REQ/CODE）由 `tagState: .newItem(contentType:)` 自动关联，
    /// 无需额外注入。
    private static func seedTagFilterFixture(repository: TagRepository)
    {
        let clipIDs = ClipTestData.tagFilterFixtureClipIDs
        let tagIDs = ClipTestData.tagFilterFixtureUserTagIDs

        let importantTag = ClipTag(
            id: .user(tagIDs[0]),
            name: "重要",
            color: .rose,
            source: .user
        )
        let pendingTag = ClipTag(
            id: .user(tagIDs[1]),
            name: "待处理",
            color: .amber,
            source: .user
        )

        // tag-result-1: 重要、待处理
        // tag-result-2: 重要
        // tag-result-3: 重要、待处理
        // tag-result-4: 重要、待处理
        let attachments: [(clipIndex: Int, tag: ClipTag)] = [
            (0, importantTag),
            (0, pendingTag),
            (1, importantTag),
            (2, importantTag),
            (2, pendingTag),
            (3, importantTag),
            (3, pendingTag)
        ]

        for attachment in attachments
        {
            let clipID = clipIDs[attachment.clipIndex]
            do
            {
                try repository.apply(.createAndAttach(tag: attachment.tag, clipID: clipID))
            } catch
            {
                LogCategory.app.error("TagUITestSupport seedTagFilterFixture failed")
            }
        }
    }

    /// Phase 5：注入迁移夹具。
    ///
    /// 创建 100 条 legacy ClipItem（`tagState: .legacy`，待迁移）和 1 条 removed
    /// disposition 条目。迁移启动后，100 条 legacy 条目根据 ContentType 关联自身
    /// 系统标签；removed 条目不恢复系统标签，UI 显示「+」。
    ///
    /// 使用 `save`（INSERT）而非 `update`：迁移夹具要求 tagState 必须是 `.legacy`，
    /// `update` 会保留数据库中已有的 tagState，破坏夹具一致性。CI 每次全新环境，
    /// `save` 不会冲突；本地重复运行时先清理数据库。
    ///
    /// 101 条 INSERT 包裹在单一事务中，避免 101 次独立 fsync 导致启动阶段
    /// 主线程阻塞过长（CI 上曾触发 watchdog 终止，XCUITest 报 "no process ID"）。
    private static func seedMigrationFixture(store: EncryptedStore, repository: TagRepository)
    {
        do
        {
            try store.database.transaction
            {
                for clip in ClipTestData.tagMigrationFixtureClips
                {
                    try store.save(clip)
                }
            }
        } catch
        {
            // 本地重复运行可能主键冲突，忽略；CI 全新环境不会触发。
            LogCategory.app.error("TagUITestSupport seedMigrationFixture failed")
        }
    }
}

// MARK: - FailOnceTagRepository

/// 包装正式 `TagRepository`，使指定闭集 operation 仅第一次抛 `.persistenceFailed`。
///
/// 不读取或记录 associated value。每种 operation 独立计数，失败一次后恢复正常。
/// 仅在 `CLIPMIND_DEV` 构建中可用，用于 Phase 2/4 验证失败回滚和 retry 行为。
final class FailOnceTagRepository: TagRepository
{
    private let wrapped: TagRepository
    private let failOperation: TagUITestSupport.FailOnceOperation
    private var hasFailedCreate = false
    private var hasFailedAttach = false
    private var hasFailedDetach = false
    private var hasFailedRename = false
    private var hasFailedDelete = false
    private var hasFailedMigrate = false

    init(wrapping: TagRepository, failOperation: TagUITestSupport.FailOnceOperation)
    {
        self.wrapped = wrapping
        self.failOperation = failOperation
    }

    func loadSnapshot() throws -> TagSnapshot
    {
        try wrapped.loadSnapshot()
    }

    func apply(_ mutation: TagMutation) throws
    {
        switch mutation
        {
        case .createAndAttach:
            if failOperation == .create, !hasFailedCreate
            {
                hasFailedCreate = true
                throw TagError.persistenceFailed
            }
        case .attach:
            if failOperation == .attach, !hasFailedAttach
            {
                hasFailedAttach = true
                throw TagError.persistenceFailed
            }
        case .detach:
            if failOperation == .detach, !hasFailedDetach
            {
                hasFailedDetach = true
                throw TagError.persistenceFailed
            }
        case .rename:
            if failOperation == .rename, !hasFailedRename
            {
                hasFailedRename = true
                throw TagError.persistenceFailed
            }
        case .delete:
            if failOperation == .delete, !hasFailedDelete
            {
                hasFailedDelete = true
                throw TagError.persistenceFailed
            }
        }
        try wrapped.apply(mutation)
    }

    func migrateNextBatch(limit: Int) throws -> TagMigrationBatchResult
    {
        if failOperation == .migrate, !hasFailedMigrate
        {
            hasFailedMigrate = true
            throw TagError.persistenceFailed
        }
        return try wrapped.migrateNextBatch(limit: limit)
    }
}
#endif
