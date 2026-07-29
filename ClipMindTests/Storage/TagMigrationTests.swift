@testable import ClipMind
import SQLite
import XCTest

final class TagMigrationTests: XCTestCase
{
    private var dbPath: URL!
    private var store: EncryptedStore!

    override func setUpWithError() throws
    {
        dbPath = try TestDatabaseHelper.makeTempDBPath(suffix: "_migration")
        store = try EncryptedStore(
            dbPath: dbPath,
            key: TestDatabaseHelper.makeTestKey()
        )
    }

    override func tearDownWithError() throws
    {
        store = nil
        TestDatabaseHelper.cleanup(at: dbPath)
    }

    // MARK: - MIG-001: 每条迁移后只关联自身系统标签

    func testMigrateAssociatesOwnSystemTag() throws
    {
        let contentTypes: [ContentType] = [.code, .link, .article, .todo, .other]
        for (index, type) in contentTypes.enumerated()
        {
            var item = ClipItem.makeText(
                "content\(index)",
                contentType: type,
                sourceApp: "com.test",
                sourceAppName: "Test"
            )
            item.tagState = .legacy
            try store.save(item)
        }

        let result = try store.migrateNextBatch(limit: 100)

        XCTAssertEqual(result.migratedCount, contentTypes.count)
        XCTAssertEqual(result.remainingCount, 0)

        let loaded = try store.loadAll()
        for item in loaded
        {
            XCTAssertEqual(item.tagState.systemTagDisposition, .associated)
            XCTAssertEqual(item.tagState.migrationVersion, ClipTagState.currentMigrationVersion)
            XCTAssertEqual(item.tagState.orderedTagIDs, [.system(item.contentType)])
        }
    }

    // MARK: - MIG-002: 批次中断后 remainingCount 正确，重开后继续

    func testBatchInterruptionResumesCorrectly() throws
    {
        for index in 0..<10
        {
            var item = ClipItem.makeText(
                "content\(index)",
                contentType: .article,
                sourceApp: "com.test",
                sourceAppName: "Test"
            )
            item.tagState = .legacy
            try store.save(item)
        }

        // 第一批只迁移 3 条
        let result1 = try store.migrateNextBatch(limit: 3)
        XCTAssertEqual(result1.migratedCount, 3)
        XCTAssertEqual(result1.remainingCount, 7, "剩余 7 条待迁移")

        // 第二批迁移 5 条
        let result2 = try store.migrateNextBatch(limit: 5)
        XCTAssertEqual(result2.migratedCount, 5)
        XCTAssertEqual(result2.remainingCount, 2, "剩余 2 条待迁移")

        // 第三批完成
        let result3 = try store.migrateNextBatch(limit: 100)
        XCTAssertEqual(result3.migratedCount, 2)
        XCTAssertEqual(result3.remainingCount, 0, "迁移完成")
    }

    // MARK: - MIG-003: 重复运行不产生重复 ID

    func testRepeatedRunNoDuplicateIDs() throws
    {
        var item = ClipItem.makeText(
            "content",
            contentType: .code,
            sourceApp: "com.test",
            sourceAppName: "Test"
        )
        item.tagState = .legacy
        try store.save(item)

        _ = try store.migrateNextBatch(limit: 100)
        _ = try store.migrateNextBatch(limit: 100)
        _ = try store.migrateNextBatch(limit: 100)

        let loaded = try store.loadAll()
        XCTAssertEqual(loaded.count, 1)
        let tagIDs = loaded[0].tagState.orderedTagIDs
        let uniqueIDs = Set(tagIDs)
        XCTAssertEqual(tagIDs.count, uniqueIDs.count, "不应有重复标签 ID")
        XCTAssertEqual(tagIDs, [.system(.code)])
    }

    // MARK: - .removed 系统标签处置不被恢复

    func testRemovedDispositionNotRestored() throws
    {
        var item = ClipItem.makeText(
            "content",
            contentType: .code,
            sourceApp: "com.test",
            sourceAppName: "Test"
        )
        item.tagState = ClipTagState(
            orderedTagIDs: [],
            systemTagDisposition: .removed,
            migrationVersion: 0
        )
        try store.save(item)

        let result = try store.migrateNextBatch(limit: 100)
        XCTAssertEqual(result.migratedCount, 1)

        let loaded = try store.loadAll()
        XCTAssertEqual(loaded[0].tagState.systemTagDisposition, .removed)
        XCTAssertTrue(loaded[0].tagState.orderedTagIDs.isEmpty, "removed 状态不应恢复系统标签")
        XCTAssertEqual(loaded[0].tagState.migrationVersion, ClipTagState.currentMigrationVersion)
    }

    // MARK: - 已迁移条目不被重复处理

    func testAlreadyMigratedSkipped() throws
    {
        let item = ClipItem.makeText(
            "content",
            contentType: .code,
            sourceApp: "com.test",
            sourceAppName: "Test"
        )
        try store.save(item)

        let result = try store.migrateNextBatch(limit: 100)
        XCTAssertEqual(result.migratedCount, 0, "新条目已关联，不需要迁移")
        XCTAssertEqual(result.remainingCount, 0)
    }

    // MARK: - .associated 状态保留现有系统标签

    func testAssociatedDispositionPreservesSystemTag() throws
    {
        var item = ClipItem.makeText(
            "content",
            contentType: .article,
            sourceApp: "com.test",
            sourceAppName: "Test"
        )
        item.tagState = ClipTagState(
            orderedTagIDs: [.system(.article)],
            systemTagDisposition: .associated,
            migrationVersion: 0
        )
        try store.save(item)

        let result = try store.migrateNextBatch(limit: 100)
        XCTAssertEqual(result.migratedCount, 1)

        let loaded = try store.loadAll()
        XCTAssertEqual(loaded[0].tagState.orderedTagIDs, [.system(.article)])
        XCTAssertEqual(loaded[0].tagState.systemTagDisposition, .associated)
        XCTAssertEqual(loaded[0].tagState.migrationVersion, ClipTagState.currentMigrationVersion)
    }

    // MARK: - 11 种 ContentType 覆盖

    func testAllContentTypesMigrateCorrectly() throws
    {
        let allTypes = ContentType.allCases
        for (index, type) in allTypes.enumerated()
        {
            var item = ClipItem.makeText(
                "content\(index)",
                contentType: type,
                sourceApp: "com.test",
                sourceAppName: "Test"
            )
            item.tagState = .legacy
            try store.save(item)
        }

        let result = try store.migrateNextBatch(limit: 100)
        XCTAssertEqual(result.migratedCount, allTypes.count)
        XCTAssertEqual(result.remainingCount, 0)

        let loaded = try store.loadAll()
        for item in loaded
        {
            XCTAssertEqual(item.tagState.orderedTagIDs, [.system(item.contentType)])
            XCTAssertEqual(item.tagState.systemTagDisposition, .associated)
        }
    }

    // MARK: - 迁移协调器测试

    func testCoordinatorMigratesAllBatches() async throws
    {
        for index in 0..<250
        {
            var item = ClipItem.makeText(
                "content\(index)",
                contentType: .article,
                sourceApp: "com.test",
                sourceAppName: "Test"
            )
            item.tagState = .legacy
            try store.save(item)
        }

        let logger = DefaultTagOperationLogger()
        let service = TagService(repository: store, logger: logger)
        let coordinator = TagMigrationCoordinator(service: service)

        try await coordinator.resume()

        let loaded = try store.loadAll()
        XCTAssertEqual(loaded.count, 250)
        for item in loaded
        {
            XCTAssertEqual(item.tagState.migrationVersion, ClipTagState.currentMigrationVersion)
        }
    }

    func testCoordinatorPostsNotificationOnProgress() async throws
    {
        for index in 0..<150
        {
            var item = ClipItem.makeText(
                "content\(index)",
                contentType: .code,
                sourceApp: "com.test",
                sourceAppName: "Test"
            )
            item.tagState = .legacy
            try store.save(item)
        }

        let logger = DefaultTagOperationLogger()
        let service = TagService(repository: store, logger: logger)
        let center = NotificationCenter()
        let coordinator = TagMigrationCoordinator(
            service: service,
            notificationCenter: center
        )

        let expectation = XCTestExpectation(description: "收到标签更新通知")
        let observer = center.addObserver(
            forName: .clipTagsDidUpdate,
            object: nil,
            queue: nil
        ) { _ in
            expectation.fulfill()
        }

        try await coordinator.resume()
        wait(for: [expectation], timeout: 10)
        center.removeObserver(observer)
    }
}
