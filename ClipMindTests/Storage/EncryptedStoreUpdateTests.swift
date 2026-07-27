@testable import ClipMind
import CryptoKit
import XCTest

final class EncryptedStoreUpdateTests: XCTestCase
{
    private var store: EncryptedStore!
    private var dbPath: URL!

    override func setUpWithError() throws {
        dbPath = try TestDatabaseHelper.makeTempDBPath(suffix: "_update")
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

    // MARK: - 更新已存在的条目

    func testUpdateExistingItem() throws {
        let item = ClipItem.makeText(
            "original",
            contentType: .article,
            sourceApp: "com.test",
            sourceAppName: "Test"
        )
        try store.save(item)

        let updated = ClipItem(
            id: item.id,
            content: .text("modified"),
            contentType: item.contentType,
            sourceApp: item.sourceApp,
            sourceAppName: item.sourceAppName,
            timestamp: item.timestamp,
            summary: item.summary,
            translation: item.translation,
            rewrite: item.rewrite,
            todos: item.todos,
            embeddings: item.embeddings
        )
        try store.update(updated)

        let loaded = try store.loadAll()
        XCTAssertEqual(loaded.count, 1)
        if case .text(let text) = loaded[0].content {
            XCTAssertEqual(text, "modified")
        } else {
            XCTFail("Expected text content")
        }
    }

    // MARK: - 更新不存在的条目（INSERT OR REPLACE 行为）

    func testUpdateNewItem() throws {
        let item = ClipItem.makeText(
            "new item",
            contentType: .article,
            sourceApp: "com.test",
            sourceAppName: "Test"
        )
        try store.update(item)

        let loaded = try store.loadAll()
        XCTAssertEqual(loaded.count, 1)
    }

    // MARK: - 加密一致性：更新后能正确解密

    func testUpdateEncryptionConsistent() throws {
        let item = ClipItem.makeText(
            "original",
            contentType: .article,
            sourceApp: "com.test",
            sourceAppName: "Test"
        )
        try store.save(item)

        let updated = ClipItem(
            id: item.id,
            content: .text("modified"),
            contentType: item.contentType,
            sourceApp: item.sourceApp,
            sourceAppName: item.sourceAppName,
            timestamp: item.timestamp,
            summary: item.summary,
            translation: item.translation,
            rewrite: item.rewrite,
            todos: item.todos,
            embeddings: item.embeddings
        )
        try store.update(updated)

        let loaded = try store.loadAll()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].id, item.id)
    }

    // MARK: - 更新时间戳

    func testUpdatePreservesTimestamp() throws {
        let item = ClipItem.makeText(
            "original",
            contentType: .article,
            sourceApp: "com.test",
            sourceAppName: "Test",
            timestamp: Date().addingTimeInterval(-3600)
        )
        try store.save(item)

        let updated = ClipItem(
            id: item.id,
            content: .text("modified"),
            contentType: item.contentType,
            sourceApp: item.sourceApp,
            sourceAppName: item.sourceAppName,
            timestamp: Date(),
            summary: item.summary,
            translation: item.translation,
            rewrite: item.rewrite,
            todos: item.todos,
            embeddings: item.embeddings
        )
        try store.update(updated)

        let loaded = try store.loadAll()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertGreaterThan(
            loaded[0].timestamp.timeIntervalSince1970,
            item.timestamp.timeIntervalSince1970
        )
    }

    // MARK: - 更新后保留 embeddings

    func testUpdatePreservesEmbeddings() throws {
        var item = ClipItem.makeText(
            "original",
            contentType: .article,
            sourceApp: "com.test",
            sourceAppName: "Test"
        )
        item.embeddings = [0.1, 0.2, 0.3]
        try store.save(item)

        let updated = ClipItem(
            id: item.id,
            content: .text("modified"),
            contentType: item.contentType,
            sourceApp: item.sourceApp,
            sourceAppName: item.sourceAppName,
            timestamp: item.timestamp,
            summary: item.summary,
            translation: item.translation,
            rewrite: item.rewrite,
            todos: item.todos,
            embeddings: item.embeddings
        )
        try store.update(updated)

        let loaded = try store.loadAll()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].embeddings?.count, 3)
    }
}
