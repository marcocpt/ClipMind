@testable import ClipMind
import Foundation
import SQLite
import XCTest

/// F1.14 Phase 5 任务 5 步骤 1：标签领域性能测试。
///
/// 固定 1000 条夹具，每项预热 1 次、测量 20 次，保存原始毫秒样本；
/// 升序第 19 个样本为 nearest-rank p95（20 样本时 index 18）。
/// 运行环境：macOS 15 arm64 Release（phase-5 计划）。
final class TagPerformanceTests: XCTestCase
{
    // MARK: - 常量

    private let fixtureCount = 1000
    private let measurementCount = 20
    private let p95Index = 18

    // MARK: - 性能阈值（毫秒）

    private let tagSearchP95LimitMs = 100.0
    private let tagToggleP95LimitMs = 50.0
    private let tagFilterP95LimitMs = 200.0
    private let tagMigrationP95LimitMs = 3000.0

    private var dbPath: URL!
    private var store: EncryptedStore!
    private var service: TagService!

    override func setUpWithError() throws
    {
        dbPath = try TestDatabaseHelper.makeTempDBPath(suffix: "_tagperf")
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

    // MARK: - PERF：tagSearch p95 ≤ 100ms

    /// 按标签 ID 检索全部关联条目（加载快照并扫描 tagStatesByClipID）。
    func testTagSearch_p95Under100ms() throws
    {
        let targetTagID = seedClipsWithUserTag(attachedCount: fixtureCount / 2)

        // 预热 1 次
        let warmup = try store.loadSnapshot()
        _ = warmup.tagStatesByClipID.filter { $0.value.orderedTagIDs.contains(targetTagID) }

        var samples: [Double] = []
        for _ in 0..<measurementCount
        {
            let elapsedMs = try measureMilliseconds
            {
                let snapshot = try store.loadSnapshot()
                let matching = snapshot.tagStatesByClipID.filter
                {
                    $0.value.orderedTagIDs.contains(targetTagID)
                }
                XCTAssertEqual(matching.count, fixtureCount / 2, "应检索到半数关联条目")
            }
            samples.append(elapsedMs)
        }
        assertP95(samples, limit: tagSearchP95LimitMs, name: "tagSearch")
    }

    // MARK: - PERF：tagAssociationToggle p95 ≤ 50ms

    /// 切换标签关联（attach/detach）通过 TagService 业务边界。
    func testTagAssociationToggle_p95Under50ms() async throws
    {
        let clipID = seedSingleClipWithUserTag()

        // 预热 1 次：attach 再 detach
        _ = try await service.setAttached(true, tagID: toggleTagID, clipID: clipID)
        _ = try await service.setAttached(false, tagID: toggleTagID, clipID: clipID)

        var samples: [Double] = []
        for index in 0..<measurementCount
        {
            let shouldAttach = (index % 2 == 0)
            let elapsedMs = try await measureMillisecondsAsync
            {
                _ = try await service.setAttached(shouldAttach, tagID: toggleTagID, clipID: clipID)
            }
            samples.append(elapsedMs)
        }
        assertP95(samples, limit: tagToggleP95LimitMs, name: "tagAssociationToggle")
    }

    // MARK: - PERF：tagFilter p95 ≤ 200ms

    /// CompositeClipFilter 在 1000 条夹具上执行搜索 + 来源 + 标签 AND 交集。
    func testTagFilter_p95Under200ms() throws
    {
        let targetTagID = seedClipsWithUserTag(attachedCount: fixtureCount / 2)
        let clips = try store.loadAll()
        XCTAssertEqual(clips.count, fixtureCount, "夹具应加载 1000 条")

        let intent = ClipFilterIntent(
            query: "需求",
            selectedSourceApps: ["Test"],
            allSourceApps: ["Test"],
            selectedTagIDs: [targetTagID]
        )

        // 预热 1 次
        let snapshot = try store.loadSnapshot()
        _ = CompositeClipFilter.filter(clips, intent: intent, snapshot: snapshot)

        var samples: [Double] = []
        for _ in 0..<measurementCount
        {
            let elapsedMs = try measureMilliseconds
            {
                let snap = try store.loadSnapshot()
                let filtered = CompositeClipFilter.filter(clips, intent: intent, snapshot: snap)
                XCTAssertEqual(filtered.count, fixtureCount / 2, "标签筛选应保留半数条目")
            }
            samples.append(elapsedMs)
        }
        assertP95(samples, limit: tagFilterP95LimitMs, name: "tagFilter")
    }

    // MARK: - PERF：tagMigration p95 ≤ 3s

    /// migrateNextBatch 在 1000 条 legacy 夹具上执行一次性迁移。
    func testTagMigration_p95Under3s() throws
    {
        // 预热 1 次：使用独立 store，避免污染测量样本
        let warmupStore = try makeFreshLegacyStore(suffix: "_warmup")
        let warmupPath = legacyDBPath
        _ = try warmupStore.migrateNextBatch(limit: fixtureCount)
        TestDatabaseHelper.cleanup(at: warmupPath)

        var samples: [Double] = []
        for index in 0..<measurementCount
        {
            let legacyStore = try makeFreshLegacyStore(suffix: "_m\(index)")
            let migratedDBPath = legacyDBPath
            let elapsedMs = try measureMilliseconds
            {
                let result = try legacyStore.migrateNextBatch(limit: fixtureCount)
                XCTAssertEqual(result.migratedCount, fixtureCount, "应迁移全部 1000 条")
                XCTAssertEqual(result.remainingCount, 0, "迁移完成后无剩余")
            }
            samples.append(elapsedMs)
            TestDatabaseHelper.cleanup(at: migratedDBPath)
        }
        assertP95(samples, limit: tagMigrationP95LimitMs, name: "tagMigration")
    }

    // MARK: - 夹具与辅助

    private var toggleTagID: ClipTagID = .user()

    private var legacyDBPath: URL = URL(fileURLWithPath: "/dev/null")

    /// 创建 1000 条夹具 ClipItem，前 attachedCount 条关联用户标签。
    /// 返回用户标签 ID（用于检索/筛选）。
    private func seedClipsWithUserTag(attachedCount: Int) -> ClipTagID
    {
        let userTag = ClipTag(
            id: .user(UUID(uuidString: "00000000-0000-4000-8000-0000000000a1")!),
            name: "perf-search",
            color: .blue,
            source: .user
        )
        var clipIDs: [UUID] = []
        for index in 0..<fixtureCount
        {
            let item = ClipItem.makeText(
                "需求条目 \(index)",
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
            clipIDs.append(item.id)
        }
        do
        {
            try store.apply(.createAndAttach(tag: userTag, clipID: clipIDs[0]))
            for index in 1..<attachedCount
            {
                try store.apply(.attach(tagID: userTag.id, clipID: clipIDs[index]))
            }
        } catch
        {
            XCTFail("夹具用户标签关联失败")
        }
        return userTag.id
    }

    /// 创建单条夹具并关联一个用户标签（用于 toggle 测试）。
    /// 返回 clipID，并设置 `toggleTagID`。
    @discardableResult
    private func seedSingleClipWithUserTag() -> UUID
    {
        let clip = ClipItem.makeText(
            "toggle-target",
            contentType: .article,
            sourceApp: "com.test",
            sourceAppName: "Test"
        )
        let toggleTag = ClipTag(
            id: .user(UUID(uuidString: "00000000-0000-4000-8000-0000000000a2")!),
            name: "perf-toggle",
            color: .rose,
            source: .user
        )
        toggleTagID = toggleTag.id
        do
        {
            try store.save(clip)
            try store.apply(.createAndAttach(tag: toggleTag, clipID: clip.id))
            // 先 detach，使测量从「未关联」开始
            try store.apply(.detach(tagID: toggleTag.id, clipID: clip.id))
        } catch
        {
            XCTFail("toggle 夹具初始化失败")
        }
        return clip.id
    }

    /// 创建包含 1000 条 legacy ClipItem 的独立 store，用于迁移性能测量。
    /// 设置 `legacyDBPath` 供调用方清理。
    private func makeFreshLegacyStore(suffix: String) throws -> EncryptedStore
    {
        let path = try TestDatabaseHelper.makeTempDBPath(suffix: suffix)
        legacyDBPath = path
        let legacyStore = try EncryptedStore(
            dbPath: path,
            key: TestDatabaseHelper.makeTestKey()
        )
        for index in 0..<fixtureCount
        {
            var item = ClipItem.makeText(
                "迁移夹具 \(index)",
                contentType: .article,
                sourceApp: "com.test",
                sourceAppName: "Test"
            )
            item.tagState = .legacy
            try legacyStore.save(item)
        }
        return legacyStore
    }

    /// 同步测量闭包耗时（毫秒）。
    private func measureMilliseconds(_ block: () throws -> Void) rethrows -> Double
    {
        let clock = ContinuousClock()
        let start = clock.now
        try block()
        return milliseconds(clock.now - start)
    }

    /// 异步测量闭包耗时（毫秒）。
    private func measureMillisecondsAsync(
        _ block: () async throws -> Void
    ) async rethrows -> Double
    {
        let clock = ContinuousClock()
        let start = clock.now
        try await block()
        return milliseconds(clock.now - start)
    }

    /// Duration 转毫秒。
    private func milliseconds(_ duration: Duration) -> Double
    {
        let (seconds, attoseconds) = duration.components
        return Double(seconds) * 1000.0 + Double(attoseconds) / 1e15
    }

    /// 计算 nearest-rank p95 并断言；保存原始样本为 attachment。
    private func assertP95(_ samples: [Double], limit: Double, name: String)
    {
        let sorted = samples.sorted()
        let p95 = sorted[p95Index]
        let raw = samples.enumerated().map
        {
            "\($0.offset + 1)=\(String(format: "%.3f", $0.element))ms"
        }.joined(separator: ", ")

        XCTContext.runActivity(named: "PERF \(name)") { activity in
            let summary = XCTAttachment(string: "p95=\(String(format: "%.3f", p95))ms limit=\(limit)ms\nraw: \(raw)")
            summary.name = "perf-\(name)"
            summary.lifetime = .keepAlways
            activity.add(summary)
        }
        XCTAssertLessThan(
            p95,
            limit,
            "\(name) p95 应 ≤ \(limit)ms，实际 \(p95)ms"
        )
    }
}
