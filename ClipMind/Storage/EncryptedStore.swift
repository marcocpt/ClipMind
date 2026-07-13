import CommonCrypto
import CryptoKit
import Foundation
import IOKit
import SQLite

/// 加密存储：使用 SQLite.swift 持久化，字段级 AES-256-GCM 加密。
///
/// - 加密算法：AES-256-GCM
/// - 密钥派生：PBKDF2（设备唯一标识 + 固定 salt，10000 轮）
/// - 加密范围：content_blob、embeddings_blob 字段加密，表结构为明文
final class EncryptedStore {
    let dbPath: URL
    private let database: Connection
    private let key: SymmetricKey

    // MARK: - 表定义

    private let clips = Table("clips")
    private let idColumn = Expression<String>("id")
    private let contentBlob = Expression<Data>("content_blob")
    private let contentTypeColumn = Expression<String>("content_type")
    private let timestampColumn = Expression<Double>("timestamp")
    private let sourceAppColumn = Expression<String?>("source_app")
    private let embeddingsBlob = Expression<Data?>("embeddings_blob")
    private let isSampleColumn = Expression<Bool>("is_sample")

    // MARK: - 初始化

    /// 默认初始化：使用 ~/Library/Application Support/ClipMind/clipmind.db 并基于设备 UUID 派生密钥
    convenience init() throws {
        let path = try EncryptedStore.defaultDBPath()
        try self.init(dbPath: path, key: nil)
    }

    /// 指定初始化：允许注入 dbPath 与密钥（测试用）
    /// - Parameters:
    ///   - dbPath: 数据库文件路径
    ///   - key: 自定义密钥；为 nil 时基于设备 UUID 派生
    init(dbPath: URL, key: SymmetricKey?) throws {
        self.dbPath = dbPath
        let derivedKey = key ?? EncryptedStore.deriveKeyFromDeviceUUID()
        self.key = derivedKey

        let dir = dbPath.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        self.database = try Connection(dbPath.path)
        try createTables()
    }

    // MARK: - 公开接口

    /// 保存 ClipItem：序列化为 JSON → AES-256-GCM 加密 → 写入 SQLite
    func save(_ item: ClipItem) throws {
        let json = try encodeJSON(item)
        let encryptedContent = try encrypt(json)

        let embeddingsData: Data?
        if let embeddings = item.embeddings, !embeddings.isEmpty {
            let embJson = try encodeJSON(embeddings)
            embeddingsData = try encrypt(embJson)
        } else {
            embeddingsData = nil
        }

        let id = item.id.uuidString
        let contentType = item.contentType.rawValue
        let timestamp = item.timestamp.timeIntervalSince1970
        let sourceApp = item.sourceApp
        let isSample = item.isSample

        let insert = clips.insert(
            idColumn <- id,
            contentBlob <- encryptedContent,
            contentTypeColumn <- contentType,
            timestampColumn <- timestamp,
            sourceAppColumn <- sourceApp,
            embeddingsBlob <- embeddingsData,
            isSampleColumn <- isSample
        )
        try database.run(insert)
    }

    /// 加载全部 ClipItem：从 SQLite 读取 → AES-256-GCM 解密 → 反序列化为 ClipItem
    func loadAll() throws -> [ClipItem] {
        let query = clips.select(contentBlob).order(timestampColumn.desc)
        var items: [ClipItem] = []
        for row in try database.prepare(query) {
            let encrypted = row[contentBlob]
            let json = try decrypt(encrypted)
            let item = try decodeJSON(ClipItem.self, from: json)
            items.append(item)
        }
        return items
    }

    /// 语义搜索：加载所有 embeddings → 计算余弦相似度 → 返回 Top-N
    /// - Parameters:
    ///   - query: 查询向量
    ///   - limit: 返回结果数量
    ///   - sourceApp: 可选来源 App 过滤（bundle ID 或 appName）
    /// - Returns: 按相似度降序排列的 ClipItem 数组
    func search(query: [Float], limit: Int = 5, sourceApp: String? = nil) throws -> [ClipItem] {
        guard !query.isEmpty else { return [] }

        let queryNorm = sqrt(query.reduce(Float(0)) { $0 + $1 * $1 })
        guard queryNorm > 0 else { return [] }

        var dbQuery = clips
            .select(idColumn, contentBlob, embeddingsBlob, sourceAppColumn)
            .filter(embeddingsBlob != nil)

        if let sourceApp = sourceApp {
            dbQuery = dbQuery.filter(sourceAppColumn == sourceApp)
        }

        var scored: [(item: ClipItem, score: Float)] = []
        for row in try database.prepare(dbQuery) {
            guard let embBlob = row[embeddingsBlob] else { continue }
            let embJson = try decrypt(embBlob)
            let embeddings = try decodeJSON([Float].self, from: embJson)
            guard !embeddings.isEmpty, embeddings.count == query.count else { continue }

            let embNorm = sqrt(embeddings.reduce(Float(0)) { $0 + $1 * $1 })
            guard embNorm > 0 else { continue }

            let dot = zip(query, embeddings).reduce(Float(0)) { $0 + $1.0 * $1.1 }
            let similarity = dot / (queryNorm * embNorm)

            let contentJson = try decrypt(row[contentBlob])
            let item = try decodeJSON(ClipItem.self, from: contentJson)
            scored.append((item, similarity))
        }

        return scored.sorted { $0.score > $1.score }.prefix(limit).map(\.item)
    }

    /// 清理指定天数前的数据
    func cleanup(olderThan days: Int) throws {
        let cutoff = Date().addingTimeInterval(-Double(days) * 24 * 3600)
        let cutoffTimestamp = cutoff.timeIntervalSince1970
        try database.run(clips.filter(timestampColumn < cutoffTimestamp).delete())
    }

    /// 清空所有数据（测试辅助）
    func deleteAll() throws {
        try database.run(clips.delete())
    }

    /// 统计示例数据条数（用于幂等检查）
    func countSamples() throws -> Int {
        try database.scalar(clips.filter(isSampleColumn == true).count)
    }

    /// 删除所有示例数据（is_sample=1），真实数据不受影响
    /// - Returns: 实际删除的行数
    @discardableResult
    func deleteSamples() throws -> Int {
        let changes = try database.run(clips.filter(isSampleColumn == true).delete())
        LogCategory.storage.info("已删除 \(changes) 条示例数据")
        return changes
    }

    // MARK: - 内部辅助

    private func createTables() throws {
        try database.run(clips.create(ifNotExists: true) { table in
            table.column(idColumn, primaryKey: true)
            table.column(contentBlob)
            table.column(contentTypeColumn)
            table.column(timestampColumn)
            table.column(sourceAppColumn)
            table.column(embeddingsBlob)
            table.column(isSampleColumn, defaultValue: false)
        })

        try database.run(clips.createIndex(timestampColumn, ifNotExists: true))
        try database.run(clips.createIndex(contentTypeColumn, ifNotExists: true))
        try database.run(clips.createIndex(sourceAppColumn, ifNotExists: true))

        // 对已有表迁移（补充 is_sample 列）
        try migrateSchemaIfNeeded()
    }

    /// 迁移：为已有 clips 表补充 is_sample 列。
    ///
    /// SQLite.swift 的 create(ifNotExists: true) 不会给已有表添加新列，
    /// 需通过 PRAGMA table_info 检查列存在性后 ALTER TABLE 补充。
    private func migrateSchemaIfNeeded() throws {
        let pragma = try database.prepare("PRAGMA table_info(clips)")
        var hasIsSample = false
        for row in pragma {
            // PRAGMA table_info 返回 6 列，第 2 列（index 1）为列名
            let name = row[1] as? String
            if name == "is_sample" {
                hasIsSample = true
                break
            }
        }
        if !hasIsSample {
            try database.run("ALTER TABLE clips ADD COLUMN is_sample INTEGER DEFAULT 0")
            LogCategory.storage.info("迁移: 已添加 clips.is_sample 列")
        }
    }

    // MARK: - 加密 / 解密

    /// AES-256-GCM 加密，返回 combined（nonce + ciphertext + tag）
    private func encrypt(_ data: Data) throws -> Data {
        let sealedBox = try AES.GCM.seal(data, using: key)
        guard let combined = sealedBox.combined else {
            throw EncryptedStoreError.encryptionFailed
        }
        return combined
    }

    /// AES-256-GCM 解密
    private func decrypt(_ data: Data) throws -> Data {
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(sealedBox, using: key)
    }

    // MARK: - JSON 编解码

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private func encodeJSON<T: Encodable>(_ value: T) throws -> Data {
        try EncryptedStore.encoder.encode(value)
    }

    private func decodeJSON<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try EncryptedStore.decoder.decode(type, from: data)
    }

    // MARK: - 密钥派生

    /// 使用 PBKDF2 派生 256 位密钥
    static func deriveKey(password: String, salt: Data) -> SymmetricKey {
        var derivedKey = Data(count: 32)
        let result = derivedKey.withUnsafeMutableBytes { derivedKeyBytes -> Int32 in
            salt.withUnsafeBytes { saltBytes in
                password.withCString { passwordBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBytes,
                        strlen(passwordBytes),
                        saltBytes.baseAddress,
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        10000,
                        derivedKeyBytes.baseAddress,
                        32
                    )
                }
            }
        }
        precondition(result == 0, "PBKDF2 密钥派生失败")
        return SymmetricKey(data: derivedKey)
    }

    /// 固定 salt（公开便于测试复现）
    static let fixedSalt = Data([
        0x43, 0x6C, 0x69, 0x70,
        0x4D, 0x69, 0x6E, 0x64,
        0x2D, 0x53, 0x61, 0x6C,
        0x74, 0x2D, 0x32, 0x30
    ])

    private static func deriveKeyFromDeviceUUID() -> SymmetricKey {
        deriveKey(password: getDeviceUUID(), salt: fixedSalt)
    }

    /// 获取 IOPlatformUUID 作为设备唯一标识
    static func getDeviceUUID() -> String {
        let platformExpert = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("IOPlatformExpertDevice")
        )
        defer { IOObjectRelease(platformExpert) }

        if let uuid = IORegistryEntryCreateCFProperty(
            platformExpert,
            "IOPlatformUUID" as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? String {
            return uuid
        }
        return "fallback-uuid-unknown"
    }

    // MARK: - 默认路径

    private static func defaultDBPath() throws -> URL {
        let fileManager = FileManager.default
        let appSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = appSupport.appendingPathComponent("ClipMind", isDirectory: true)
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("clipmind.db")
    }
}

// MARK: - 错误类型

enum EncryptedStoreError: Error {
    case encryptionFailed
    case decryptionFailed
    case invalidDatabasePath
}
