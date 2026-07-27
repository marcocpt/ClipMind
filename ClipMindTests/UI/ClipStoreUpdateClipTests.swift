@testable import ClipMind
import CryptoKit
import XCTest

final class ClipStoreUpdateClipTests: XCTestCase
{
    private var encryptedStore: EncryptedStore!
    private var clipStore: ClipStore!
    private var dbPath: URL!

    override func setUpWithError() throws {
        dbPath = try TestDatabaseHelper.makeTempDBPath(suffix: "_clipstore_update")
        encryptedStore = try EncryptedStore(
            dbPath: dbPath,
            key: TestDatabaseHelper.makeTestKey()
        )
        clipStore = ClipStore(store: encryptedStore)
    }

    override func tearDownWithError() throws {
        clipStore = nil
        encryptedStore = nil
        if let dbPath {
            TestDatabaseHelper.cleanup(at: dbPath)
        }
        dbPath = nil
    }

    // MARK: - 更新已存在的条目

    func testUpdateClip_UpdatesClipsArray() throws {
        let item = ClipItem.makeText(
            "original",
            contentType: .article,
            sourceApp: "com.test",
            sourceAppName: "Test"
        )
        try encryptedStore.save(item)
        clipStore.loadClips()

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
        clipStore.updateClip(updated)

        XCTAssertEqual(clipStore.clips.count, 1)
        if case .text(let text) = clipStore.clips[0].content {
            XCTAssertEqual(text, "modified")
        } else {
            XCTFail("Expected text content")
        }
    }

    // MARK: - 更新不存在的条目（INSERT OR REPLACE）

    func testUpdateClip_AddsNewClip() throws {
        let item = ClipItem.makeText(
            "new item",
            contentType: .article,
            sourceApp: "com.test",
            sourceAppName: "Test"
        )
        clipStore.updateClip(item)

        XCTAssertEqual(clipStore.clips.count, 1)
        XCTAssertEqual(clipStore.clips[0].id, item.id)
    }

    // MARK: - 更新持久化到数据库

    func testUpdateClip_PersistsToDatabase() throws {
        let item = ClipItem.makeText(
            "original",
            contentType: .article,
            sourceApp: "com.test",
            sourceAppName: "Test"
        )
        try encryptedStore.save(item)
        clipStore.loadClips()

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
        clipStore.updateClip(updated)

        // 重新从数据库加载验证持久化
        let loaded = try encryptedStore.loadAll()
        XCTAssertEqual(loaded.count, 1)
        if case .text(let text) = loaded[0].content {
            XCTAssertEqual(text, "modified")
        } else {
            XCTFail("Expected text content")
        }
    }
}
