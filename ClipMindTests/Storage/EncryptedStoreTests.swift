@testable import ClipMind
import XCTest

final class EncryptedStoreTests: XCTestCase {
    private var dbPath: URL!
    private var store: EncryptedStore!

    override func setUpWithError() throws {
        dbPath = try TestDatabaseHelper.makeTempDBPath()
        store = try EncryptedStore(
            dbPath: dbPath,
            key: TestDatabaseHelper.makeTestKey()
        )
    }

    override func tearDownWithError() throws {
        store = nil
        if let dbPath {
            TestDatabaseHelper.cleanup(at: dbPath)
        }
        dbPath = nil
    }

    // MARK: - 文本类型

    func testSaveAndLoadTextItem() throws {
        let item = ClipItem.makeText(
            "Hello, ClipMind!",
            contentType: .code,
            sourceApp: "com.test.app",
            sourceAppName: "TestApp"
        )
        try store.save(item)

        let loaded = try store.loadAll()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.id, item.id)
        XCTAssertEqual(loaded.first?.contentType, .code)
        XCTAssertEqual(loaded.first?.sourceApp, "com.test.app")
        XCTAssertEqual(loaded.first?.sourceAppName, "TestApp")

        if case .text(let value) = loaded.first?.content {
            XCTAssertEqual(value, "Hello, ClipMind!")
        } else {
            XCTFail("Expected text content")
        }
    }

    // MARK: - 图片类型

    func testSaveAndLoadImageItem() throws {
        let imageData = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        let item = ClipItem.makeImage(
            imageData,
            contentType: .other,
            sourceApp: "com.test.app",
            sourceAppName: "TestApp"
        )
        try store.save(item)

        let loaded = try store.loadAll()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.id, item.id)
        if case .image(let value) = loaded.first?.content {
            XCTAssertEqual(value, imageData)
        } else {
            XCTFail("Expected image content")
        }
    }

    // MARK: - 文件路径类型

    func testSaveAndLoadFilePathItem() throws {
        let urls = [
            URL(fileURLWithPath: "/tmp/file1.txt"),
            URL(fileURLWithPath: "/tmp/file2.txt")
        ]
        let item = ClipItem.makeFilePath(
            urls,
            contentType: .other,
            sourceApp: "com.test.app",
            sourceAppName: "TestApp"
        )
        try store.save(item)

        let loaded = try store.loadAll()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.id, item.id)
        if case .filePath(let value) = loaded.first?.content {
            XCTAssertEqual(value, urls)
        } else {
            XCTFail("Expected filePath content")
        }
    }

    // MARK: - 空数据库

    func testLoadAllEmpty() throws {
        let loaded = try store.loadAll()
        XCTAssertTrue(loaded.isEmpty)
    }

    // MARK: - 多条保存

    func testSaveMultipleItems() throws {
        let items = (0..<5).map { index in
            ClipItem.makeText(
                "item-\(index)",
                contentType: .article,
                sourceApp: "com.test.app",
                sourceAppName: "TestApp"
            )
        }
        for item in items {
            try store.save(item)
        }

        let loaded = try store.loadAll()
        XCTAssertEqual(loaded.count, 5)
        let loadedIds = Set(loaded.map(\.id))
        for item in items {
            XCTAssertTrue(loadedIds.contains(item.id))
        }
    }

    // MARK: - 清理

    func testCleanupOldItems() throws {
        let oldItem = ClipItem.makeText(
            "old",
            contentType: .article,
            sourceApp: "com.test.app",
            sourceAppName: "TestApp"
        )
        // 通过直接构造 30 天前的数据需要绕过工厂方法，使用 JSON 编解码
        var old = oldItem
        old = ClipItem(
            id: old.id,
            content: old.content,
            contentType: old.contentType,
            sourceApp: old.sourceApp,
            sourceAppName: old.sourceAppName,
            timestamp: Date().addingTimeInterval(-31 * 24 * 3600),
            summary: old.summary,
            translation: old.translation,
            rewrite: old.rewrite,
            todos: old.todos,
            embeddings: old.embeddings
        )
        try store.save(old)

        let newItem = ClipItem.makeText(
            "new",
            contentType: .article,
            sourceApp: "com.test.app",
            sourceAppName: "TestApp"
        )
        try store.save(newItem)

        try store.cleanup(olderThan: 30)

        let loaded = try store.loadAll()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.id, newItem.id)
    }

    func testCleanupBoundary() throws {
        // 恰好 30 天前的数据应被清理（>= 30 天）
        let boundaryItem = ClipItem.makeText(
            "boundary",
            contentType: .article,
            sourceApp: "com.test.app",
            sourceAppName: "TestApp"
        )
        let boundary = ClipItem(
            id: boundaryItem.id,
            content: boundaryItem.content,
            contentType: boundaryItem.contentType,
            sourceApp: boundaryItem.sourceApp,
            sourceAppName: boundaryItem.sourceAppName,
            timestamp: Date().addingTimeInterval(-30 * 24 * 3600),
            summary: boundaryItem.summary,
            translation: boundaryItem.translation,
            rewrite: boundaryItem.rewrite,
            todos: boundaryItem.todos,
            embeddings: boundaryItem.embeddings
        )
        try store.save(boundary)

        try store.cleanup(olderThan: 30)

        let loaded = try store.loadAll()
        // 30 天前的数据被清理
        XCTAssertTrue(loaded.isEmpty || loaded.first?.id != boundary.id)
    }

    // MARK: - 搜索

    func testSearchByEmbeddings() throws {
        let itemWithEmbeddings = ClipItem(
            id: UUID(),
            content: .text("embeddings test"),
            contentType: .article,
            sourceApp: "com.test.app",
            sourceAppName: "TestApp",
            timestamp: Date(),
            summary: nil,
            translation: nil,
            rewrite: nil,
            todos: nil,
            embeddings: [1.0, 0.0, 0.0]
        )
        try store.save(itemWithEmbeddings)

        let itemWithoutEmbeddings = ClipItem.makeText(
            "no embeddings",
            contentType: .article,
            sourceApp: "com.test.app",
            sourceAppName: "TestApp"
        )
        try store.save(itemWithoutEmbeddings)

        let results = try store.search(query: [1.0, 0.0, 0.0], limit: 5)
        XCTAssertFalse(results.isEmpty)
        XCTAssertEqual(results.first?.id, itemWithEmbeddings.id)
    }

    func testSearchEmptyQuery() throws {
        let item = ClipItem(
            id: UUID(),
            content: .text("test"),
            contentType: .article,
            sourceApp: "com.test.app",
            sourceAppName: "TestApp",
            timestamp: Date(),
            summary: nil,
            translation: nil,
            rewrite: nil,
            todos: nil,
            embeddings: [0.5, 0.5]
        )
        try store.save(item)

        let results = try store.search(query: [], limit: 5)
        XCTAssertTrue(results.isEmpty, "空查询应返回空结果")
    }

    // MARK: - 清空

    func testDeleteAll() throws {
        for index in 0..<3 {
            try store.save(
                ClipItem.makeText(
                    "item-\(index)",
                    contentType: .article,
                    sourceApp: "com.test.app",
                    sourceAppName: "TestApp"
                )
            )
        }
        XCTAssertEqual(try store.loadAll().count, 3)

        try store.deleteAll()
        XCTAssertTrue(try store.loadAll().isEmpty)
    }

    // MARK: - F1.11 Bug 4：touchTimestamp 更新指定 clip 的 timestamp

    /// 验证 `touchTimestamp(id:to:)` 更新指定 clip 的 timestamp，
    /// `loadAll()` 返回的 ClipItem.timestamp 反映数据库列的新值。
    func testTouchTimestamp_UpdatesTimestamp_LoadAllReflectsNewValue() throws {
        let oldTimestamp = Date().addingTimeInterval(-3600) // 1 小时前
        let item = ClipItem.makeText(
            "touch-test-content",
            contentType: .other,
            sourceApp: "com.test",
            sourceAppName: "Test",
            timestamp: oldTimestamp
        )
        try store.save(item)

        let newTimestamp = Date().addingTimeInterval(-60) // 1 分钟前
        let updated = try store.touchTimestamp(id: item.id, to: newTimestamp)

        XCTAssertTrue(updated, "存在该 id 时应返回 true")
        let loaded = try store.loadAll()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.id, item.id)
        guard let loadedTimestamp = loaded.first?.timestamp.timeIntervalSince1970
        else {
            XCTFail("loaded.first 应存在且 timestamp 可读")
            return
        }
        XCTAssertEqual(
            loadedTimestamp,
            newTimestamp.timeIntervalSince1970,
            accuracy: 0.001,
            "loadAll 返回的 timestamp 应为 touchTimestamp 设置的新值"
        )
    }

    /// 验证 `touchTimestamp` 把 clip 移到列表最前面（按 timestamp DESC 排序）。
    func testTouchTimestamp_MovesClipToTop_WhenNewerThanOthers() throws {
        let baseTime = Date()
        let oldest = ClipItem.makeText(
            "oldest",
            contentType: .other,
            sourceApp: "com.test",
            sourceAppName: "Test",
            timestamp: baseTime.addingTimeInterval(-300)
        )
        let middle = ClipItem.makeText(
            "middle",
            contentType: .other,
            sourceApp: "com.test",
            sourceAppName: "Test",
            timestamp: baseTime.addingTimeInterval(-200)
        )
        let newest = ClipItem.makeText(
            "newest",
            contentType: .other,
            sourceApp: "com.test",
            sourceAppName: "Test",
            timestamp: baseTime.addingTimeInterval(-100)
        )
        try store.save(oldest)
        try store.save(middle)
        try store.save(newest)

        // 初始排序：newest → middle → oldest
        let initial = try store.loadAll()
        XCTAssertEqual(initial.map(\.id), [newest.id, middle.id, oldest.id])

        // 把 oldest 的 timestamp 更新为最新，应移到列表第一位
        let updated = try store.touchTimestamp(id: oldest.id, to: baseTime)
        XCTAssertTrue(updated)

        let afterTouch = try store.loadAll()
        XCTAssertEqual(
            afterTouch.map(\.id),
            [oldest.id, newest.id, middle.id],
            "oldest 的 timestamp 更新为最新后应移到列表第一位"
        )
    }

    /// 验证不存在的 id 返回 false。
    func testTouchTimestamp_NonExistentId_ReturnsFalse() throws {
        let randomId = UUID()
        let updated = try store.touchTimestamp(id: randomId)
        XCTAssertFalse(updated, "不存在的 id 应返回 false")
    }
}
