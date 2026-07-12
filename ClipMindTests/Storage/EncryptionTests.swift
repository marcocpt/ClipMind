@testable import ClipMind
import SQLite
import XCTest

final class EncryptionTests: XCTestCase {
    private var dbPath: URL!
    private var store: EncryptedStore!

    override func setUpWithError() throws {
        dbPath = try TestDatabaseHelper.makeTempDBPath(suffix: "_enc")
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

    // MARK: - AC-18: 数据库字段加密验证

    func testContentBlobIsEncrypted() throws {
        let sensitiveText = "TOP_SECRET_TOKEN_123456789"
        let item = ClipItem.makeText(
            sensitiveText,
            contentType: .code,
            sourceApp: "com.test.app",
            sourceAppName: "TestApp"
        )
        try store.save(item)

        // 读取数据库文件原始字节，确认敏感文本不在文件中
        let fileData = try Data(contentsOf: dbPath)
        XCTAssertFalse(
            containsPlaintext(fileData, sensitiveText),
            "content_blob 中的敏感文本应该被加密，不应在数据库文件中明文出现"
        )
    }

    func testEmbeddingsBlobIsEncrypted() throws {
        let embeddings: [Float] = [0.123, 0.456, 0.789, 0.012, 0.345]
        let item = ClipItem(
            id: UUID(),
            content: .text("embeddings content"),
            contentType: .article,
            sourceApp: "com.test.app",
            sourceAppName: "TestApp",
            timestamp: Date(),
            summary: nil,
            translation: nil,
            rewrite: nil,
            todos: nil,
            embeddings: embeddings
        )
        try store.save(item)

        let fileData = try Data(contentsOf: dbPath)

        // 浮点数的二进制表示不应在文件中以明文形式可识别
        // 由于浮点数二进制表示可能不直观，这里使用 SQLite.swift 直接读取原始 BLOB 验证
        let database = try Connection(dbPath.path)
        let table = Table("clips")
        let embeddingsBlob = Expression<Data>("embeddings_blob")
        let rows = try database.prepare(table.select(embeddingsBlob))
        for row in rows {
            let blob = row[embeddingsBlob]
            // 加密后的 BLOB 至少包含 nonce (12) + ciphertext + tag (16)
            XCTAssertGreaterThanOrEqual(blob.count, 28, "加密向量应至少包含 nonce+tag")

            // 原始浮点数组二进制表示不应是密文的开头部分
            let embeddingsBinary = floatsToBinary(embeddings)
            XCTAssertFalse(
                blob.starts(with: embeddingsBinary),
                "embeddings_blob 应为密文，不应以明文浮点数组开头"
            )
        }

        // 整个文件中也不应包含敏感文本
        XCTAssertFalse(containsPlaintext(fileData, "0.123"))
    }

    func testDatabaseFileStructureIsSQLite() throws {
        // 字段级加密方案下，数据库文件本身仍是合法 SQLite 文件
        // 表结构、索引等元数据是明文，但 content_blob / embeddings_blob 字段是密文
        let item = ClipItem.makeText(
            "test",
            contentType: .code,
            sourceApp: "com.test",
            sourceAppName: "Test"
        )
        try store.save(item)

        let database = try Connection(dbPath.path)
        // 可以查询表结构
        let table = Table("clips")
        let idColumn = Expression<String>("id")
        let rows = try database.prepare(table.select(idColumn))
        var found = false
        for row in rows where row[idColumn] == item.id.uuidString {
            found = true
        }
        XCTAssertTrue(found, "加密存储的数据库表结构应可被 SQLite.swift 读取")
    }

    func testRawContentBlobIsNotPlaintextJSON() throws {
        let plaintext = "PLAINTEXT_MARKER_VALUE"
        let item = ClipItem.makeText(
            plaintext,
            contentType: .code,
            sourceApp: "com.test.app",
            sourceAppName: "TestApp"
        )
        try store.save(item)

        let database = try Connection(dbPath.path)
        let table = Table("clips")
        let contentBlob = Expression<Data>("content_blob")
        let rows = try database.prepare(table.select(contentBlob))
        for row in rows {
            let blob = row[contentBlob]
            // AES-256-GCM sealed box = nonce(12) + ciphertext + tag(16)
            XCTAssertGreaterThanOrEqual(blob.count, 28, "加密内容至少 28 字节")

            // 密文不应包含明文标记
            XCTAssertFalse(
                containsPlaintext(blob, plaintext),
                "content_blob 不应包含明文标记"
            )

            // 密文也不应是 JSON 明文（不应以 { 开头）
            XCTAssertFalse(blob.starts(with: Data([0x7B])), "密文不应以 JSON '{' 开头")
        }
    }

    // MARK: - 私有辅助

    /// 在二进制数据中搜索明文字节模式，用于验证密文中不含明文标记。
    /// 直接基于 Data.range(of:) 进行字节级匹配，避免字符串编码转换。
    private func containsPlaintext(_ data: Data, _ plaintext: String) -> Bool {
        data.range(of: Data(plaintext.utf8)) != nil
    }

    private func floatsToBinary(_ floats: [Float]) -> Data {
        var data = Data()
        for value in floats {
            var valueCopy = value
            withUnsafeBytes(of: &valueCopy) { data.append(contentsOf: $0) }
        }
        return data
    }
}
