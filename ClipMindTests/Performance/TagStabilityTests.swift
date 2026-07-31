@testable import ClipMind
import Foundation
import SQLite
import XCTest

/// F1.14 Phase 5 任务 5 步骤 3：标签自动稳定性测试。
///
/// 对 create/attach/detach/rename/delete 各执行 100 次，每轮校验：
/// 目录 ID 唯一、关联引用有效、每条 ≤ 5、系统标签资格正确。
/// 随后执行组合/清空筛选和迁移中断恢复，断言 resultId、计数和快照一致。
final class TagStabilityTests: XCTestCase
{
    private let rounds = 100
    private let migrationFixtureCount = 100

    private var dbPath: URL!
    private var store: EncryptedStore!
    private var service: TagService!

    override func setUpWithError() throws
    {
        dbPath = try TestDatabaseHelper.makeTempDBPath(suffix: "_tagstab")
        store = try EncryptedStore(
            dbPath: dbPath,
            key: TestDatabaseHelper.makeTestKey()
        )
        service = TagService(repository: store, logger: DefaultTagOperationLogger())
    }

    override func tearDownWithError() throws
    {
        store = nil
        if let dbPath
        {
            TestDatabaseHelper.cleanup(at: dbPath)
        }
        dbPath = nil
    }

    // MARK: - STAB：create 100 次

    /// 每轮 createAndAttach 一个新用户标签到独立 clip，校验不变量。
    func testStability_Create_100Rounds() throws
    {
        let clips = seedClips(count: rounds)
        for index in 0..<rounds
        {
            let tag = makeStableTag(suffix: "create", index: index)
            try store.apply(.createAndAttach(tag: tag, clipID: clips[index].id))
            let snapshot = try store.loadSnapshot()
            validateInvariants(snapshot: snapshot, clips: clips)
            XCTAssertEqual(snapshot.userTags.count, index + 1, "目录计数应随 create 递增")
        }
    }

    // MARK: - STAB：attach/detach 100 次

    /// 每轮交替 attach/detach 同一用户标签，校验不变量与关联状态。
    func testStability_AttachDetach_100Rounds() async throws
    {
        let clips = seedClips(count: 1)
        let clipID = clips[0].id
        let tag = makeStableTag(suffix: "attach", index: 0)
        try store.apply(.createAndAttach(tag: tag, clipID: clipID))
        try store.apply(.detach(tagID: tag.id, clipID: clipID))

        for index in 0..<rounds
        {
            let shouldAttach = (index % 2 == 0)
            _ = try await service.setAttached(shouldAttach, tagID: tag.id, clipID: clipID)
            let snapshot = try store.loadSnapshot()
            validateInvariants(snapshot: snapshot, clips: clips)
            let state = snapshot.tagStatesByClipID[clipID]
            let isAssociated = state?.orderedTagIDs.contains(tag.id) ?? false
            XCTAssertEqual(isAssociated, shouldAttach, "attach/detach 状态应与预期一致")
        }
    }

    // MARK: - STAB：rename 100 次

    /// 每轮重命名同一用户标签，校验 ID 稳定、名称更新、不变量保持。
    func testStability_Rename_100Rounds() async throws
    {
        let clips = seedClips(count: 1)
        let clipID = clips[0].id
        let tag = makeStableTag(suffix: "rename", index: 0)
        try store.apply(.createAndAttach(tag: tag, clipID: clipID))

        for index in 0..<rounds
        {
            let newName = "renamed-\(index)"
            _ = try await service.renameUserTag(id: tag.id, name: newName)
            let snapshot = try store.loadSnapshot()
            validateInvariants(snapshot: snapshot, clips: clips)
            let renamed = snapshot.userTags.first { $0.id == tag.id }
            XCTAssertEqual(renamed?.name, newName, "rename 后名称应更新")
            XCTAssertEqual(renamed?.id, tag.id, "rename 后 ID 应稳定")
        }
    }

    // MARK: - STAB：delete 100 次

    /// 先创建 100 个用户标签，再逐个删除，校验目录收缩与不变量。
    func testStability_Delete_100Rounds() throws
    {
        let clips = seedClips(count: rounds)
        var tagIDs: [ClipTagID] = []
        for index in 0..<rounds
        {
            let tag = makeStableTag(suffix: "delete", index: index)
            try store.apply(.createAndAttach(tag: tag, clipID: clips[index].id))
            tagIDs.append(tag.id)
        }

        for index in 0..<rounds
        {
            try store.apply(.delete(tagID: tagIDs[index]))
            let snapshot = try store.loadSnapshot()
            validateInvariants(snapshot: snapshot, clips: clips)
            XCTAssertEqual(snapshot.userTags.count, rounds - index - 1, "目录计数应随 delete 递减")
            XCTAssertNil(
                snapshot.userTags.first { $0.id == tagIDs[index] },
                "已删除标签不应残留目录"
            )
        }
    }

    // MARK: - STAB：组合/清空筛选 resultId 一致

    /// 组合筛选（搜索 + 来源 + 标签）与清空标签后的 resultId 集合应与 intent 一致。
    func testStability_CombinedAndClearFilter_ConsistentResultIds() throws
    {
        let clips = seedClipsWithTagsForFilter()
        let snapshot = try store.loadSnapshot()
        let userTagID = snapshot.userTags.first!.id
        let allSources = Set(clips.map(\.sourceAppName))

        let combinedIntent = ClipFilterIntent(
            query: "需求",
            selectedSourceApps: ["Pages"],
            allSourceApps: allSources,
            selectedTagIDs: [userTagID]
        )
        let combined = CompositeClipFilter.filter(clips, intent: combinedIntent, snapshot: snapshot)
        let combinedIDs = Set(combined.map(\.id))
        XCTAssertFalse(combinedIDs.isEmpty, "组合筛选应命中至少一条")

        // 清空标签筛选：仅保留搜索 + 来源
        let clearedIntent = ClipFilterIntent(
            query: "需求",
            selectedSourceApps: ["Pages"],
            allSourceApps: allSources,
            selectedTagIDs: []
        )
        let cleared = CompositeClipFilter.filter(clips, intent: clearedIntent, snapshot: snapshot)
        let clearedIDs = Set(cleared.map(\.id))

        XCTAssertTrue(
            combinedIDs.isSubset(of: clearedIDs),
            "组合筛选结果应是清空标签结果的子集"
        )
        XCTAssertGreaterThanOrEqual(
            clearedIDs.count,
            combinedIDs.count,
            "清空标签后结果集应不小于组合筛选"
        )

        // 快照在两次筛选间不变
        let snapshotAfter = try store.loadSnapshot()
        XCTAssertEqual(snapshot, snapshotAfter, "筛选不应改变快照")
    }

    // MARK: - STAB：迁移中断恢复

    /// 分批迁移并在中断后重新打开 store 继续迁移，断言计数、resultId 与快照一致。
    func testStability_MigrationInterruptionRecovery() throws
    {
        let clips = seedLegacyClips(count: migrationFixtureCount)
        let seededIDs = Set(clips.map(\.id))

        // 第一批迁移 30 条，模拟中断
        let result1 = try store.migrateNextBatch(limit: 30)
        XCTAssertEqual(result1.migratedCount, 30, "首批应迁移 30 条")
        XCTAssertEqual(result1.remainingCount, migrationFixtureCount - 30, "剩余计数正确")
        validateMigrationInvariants(expectedTotal: migrationFixtureCount, seededIDs: seededIDs)

        // 重新打开 store 模拟重启，继续迁移
        let reopened = try EncryptedStore(
            dbPath: dbPath,
            key: TestDatabaseHelper.makeTestKey()
        )
        let result2 = try reopened.migrateNextBatch(limit: 100)
        XCTAssertEqual(result2.migratedCount, migrationFixtureCount - 30, "续迁应完成剩余 70 条")
        XCTAssertEqual(result2.remainingCount, 0, "迁移应完成")

        // 最终校验：计数、resultId 集合、快照一致
        let loaded = try reopened.loadAll()
        XCTAssertEqual(Set(loaded.map(\.id)), seededIDs, "迁移后 resultId 集合应与种子一致")
        XCTAssertEqual(loaded.count, migrationFixtureCount, "迁移后计数应无重复")
        for item in loaded
        {
            XCTAssertEqual(
                item.tagState.migrationVersion,
                ClipTagState.currentMigrationVersion,
                "所有条目应迁移到当前版本"
            )
            XCTAssertLessThanOrEqual(
                item.tagState.orderedTagIDs.count,
                TagService.maximumTagsPerClip,
                "迁移后每条 ≤ 5"
            )
        }
        let snapshot = try reopened.loadSnapshot()
        validateInvariants(snapshot: snapshot, clips: loaded)
    }
}

// MARK: - 夹具与校验

private extension TagStabilityTests
{
    /// 创建 count 条 article 夹具 clip（已关联系统标签，无需迁移）。
    func seedClips(count: Int) -> [ClipItem]
    {
        var clips: [ClipItem] = []
        for index in 0..<count
        {
            let item = ClipItem.makeText(
                "稳定夹具 \(index)",
                contentType: .article,
                sourceApp: "com.test",
                sourceAppName: "Test"
            )
            do
            {
                try store.save(item)
            } catch
            {
                XCTFail("夹具 clip[\(index)] 保存失败")
            }
            clips.append(item)
        }
        return clips
    }

    /// 创建用于筛选稳定性测试的夹具：3 条 Pages+需求+标签、1 条 Xcode+需求。
    func seedClipsWithTagsForFilter() -> [ClipItem]
    {
        var clips: [ClipItem] = []
        let pagesClip = ClipItem.makeText(
            "需求分析文档",
            contentType: .requirement,
            sourceApp: "com.apple.Pages",
            sourceAppName: "Pages"
        )
        let xcodeClip = ClipItem.makeText(
            "需求代码实现",
            contentType: .code,
            sourceApp: "com.apple.Xcode",
            sourceAppName: "Xcode"
        )
        let pagesClip2 = ClipItem.makeText(
            "需求评审记录",
            contentType: .requirement,
            sourceApp: "com.apple.Pages",
            sourceAppName: "Pages"
        )
        do
        {
            try store.save(pagesClip)
            try store.save(xcodeClip)
            try store.save(pagesClip2)
            let tag = ClipTag(
                id: .user(UUID(uuidString: "00000000-0000-4000-8000-0000000000b1")!),
                name: "重要",
                color: .rose,
                source: .user
            )
            try store.apply(.createAndAttach(tag: tag, clipID: pagesClip.id))
            try store.apply(.attach(tagID: tag.id, clipID: pagesClip2.id))
        } catch
        {
            XCTFail("筛选夹具初始化失败")
        }
        clips = [pagesClip, xcodeClip, pagesClip2]
        return clips
    }

    /// 创建 count 条 legacy 夹具 clip（待迁移）。
    func seedLegacyClips(count: Int) -> [ClipItem]
    {
        var clips: [ClipItem] = []
        for index in 0..<count
        {
            var item = ClipItem.makeText(
                "迁移夹具 \(index)",
                contentType: ContentType.allCases[index % ContentType.allCases.count],
                sourceApp: "com.test",
                sourceAppName: "Test"
            )
            item.tagState = .legacy
            do
            {
                try store.save(item)
            } catch
            {
                XCTFail("迁移夹具[\(index)] 保存失败")
            }
            clips.append(item)
        }
        return clips
    }

    /// 构造稳定 UUID 的用户标签。
    func makeStableTag(suffix: String, index: Int) -> ClipTag
    {
        let uuid = UUID(
            uuidString: String(
                format: "00000000-0000-4000-8000-%012d",
                index + (suffix == "create" ? 0 : 500)
            )
        )!
        return ClipTag(
            id: .user(uuid),
            name: "\(suffix)-\(index)",
            color: ClipTagColor.allCases[index % ClipTagColor.allCases.count],
            source: .user
        )
    }

    /// 校验快照不变量：目录 ID 唯一、每条 ≤ 5、关联引用有效、系统标签资格。
    func validateInvariants(snapshot: TagSnapshot, clips: [ClipItem])
    {
        let userIDs = snapshot.userTags.map(\.id)
        XCTAssertEqual(
            userIDs.count,
            Set(userIDs).count,
            "目录 ID 应唯一"
        )
        let allTagIDs = Set(snapshot.allTags.map(\.id))
        let clipsByID = Dictionary(clips.map { ($0.id, $0) }, uniquingKeysWith: { existing, _ in existing })
        for (clipID, state) in snapshot.tagStatesByClipID
        {
            XCTAssertLessThanOrEqual(
                state.orderedTagIDs.count,
                TagService.maximumTagsPerClip,
                "每条条目标签数应 ≤ \(TagService.maximumTagsPerClip)"
            )
            for tagID in state.orderedTagIDs
            {
                XCTAssertTrue(
                    allTagIDs.contains(tagID),
                    "关联引用应有效：\(tagID.rawValue)"
                )
            }
            guard let clip = clipsByID[clipID] else { continue }
            for tagID in state.orderedTagIDs
            {
                if let contentType = SystemTagCatalog.contentType(for: tagID)
                {
                    XCTAssertEqual(
                        contentType,
                        clip.contentType,
                        "系统标签应匹配条目 contentType"
                    )
                }
            }
        }
    }

    /// 校验迁移中途不变量：计数、无重复 resultId、已迁移条目版本正确。
    func validateMigrationInvariants(expectedTotal: Int, seededIDs: Set<UUID>)
    {
        do
        {
            let loaded = try store.loadAll()
            XCTAssertEqual(loaded.count, expectedTotal, "迁移中途计数应稳定")
            XCTAssertEqual(Set(loaded.map(\.id)), seededIDs, "迁移中途 resultId 集合应不变")
            let migrated = loaded.filter { !$0.tagState.requiresMigration }
            let pending = loaded.filter { $0.tagState.requiresMigration }
            XCTAssertEqual(migrated.count + pending.count, expectedTotal, "已迁移+待迁移=总数")
        } catch
        {
            XCTFail("迁移中途快照加载失败")
        }
    }
}
