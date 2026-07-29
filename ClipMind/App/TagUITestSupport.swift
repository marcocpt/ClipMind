#if CLIPMIND_DEV
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
enum TagUITestSupport
{
    // MARK: - 启动参数常量

    static let tagFixtureArg = "--UITEST_TAG_FIXTURE"
    static let tagEmptyClipArg = "--UITEST_TAG_EMPTY_CLIP"
    static let tagLimitFixtureArg = "--UITEST_TAG_LIMIT_FIXTURE"
    static let tagFailOnceArg = "--UITEST_TAG_FAIL_ONCE"

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
    /// 先持久化 `previewClips` 到 `EncryptedStore`（确保 tag state 存在），
    /// 再通过 `repository.apply` 注入用户标签关联或移除系统标签。
    static func seedFixturesIfNeeded(store: EncryptedStore, repository: TagRepository)
    {
        guard shouldSeedTagFixture || shouldSeedLimitFixture || shouldSeedEmptyClip
        else
        {
            return
        }

        // 先持久化 previewClips，确保 tag state 存在
        for clip in ClipTestData.previewClips
        {
            do
            {
                try store.save(clip)
            } catch
            {
                LogCategory.app.error("TagUITestSupport save clip failed")
            }
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

    /// 为 `previewClips[0]` 注入 5 个用户标签（上限测试）。
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
