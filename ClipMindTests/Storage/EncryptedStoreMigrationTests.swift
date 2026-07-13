@testable import ClipMind
import SQLite
import XCTest

final class EncryptedStoreMigrationTests: XCTestCase {
    private var dbPath: URL!

    override func setUpWithError() throws {
        dbPath = try TestDatabaseHelper.makeTempDBPath(suffix: "_migration")
    }

    override func tearDownWithError() throws {
        if let dbPath {
            TestDatabaseHelper.cleanup(at: dbPath)
        }
        dbPath = nil
    }

    // MARK: - TC-F18-034 旧库迁移后 is_sample 列存在

    /// 验证迁移为旧库添加 is_sample 列。
    ///
    /// 步骤：
    /// 1. 用 EncryptedStore 创建新库并保存数据
    /// 2. 关闭后用 raw SQL 删除 is_sample 列（模拟旧库）
    /// 3. 重新用 EncryptedStore 打开（触发 migrateSchemaIfNeeded）
    /// 4. countSamples() 可正常执行证明列已添加
    func testMigrationAddsIsSampleColumn() throws {
        // 1. 创建新库并保存数据
        do {
            let store = try EncryptedStore(
                dbPath: dbPath,
                key: TestDatabaseHelper.makeTestKey()
            )
            try store.save(
                ClipItem.makeText(
                    "migration test",
                    contentType: .article,
                    sourceApp: "com.test",
                    sourceAppName: "Test"
                )
            )
        } // store 释放，Connection 关闭

        // 2. 用 raw SQL 删除 is_sample 列模拟旧库
        do {
            let connection = try Connection(dbPath.path)
            try connection.run("ALTER TABLE clips DROP COLUMN is_sample")
        } // connection 释放

        // 3. 重新用 EncryptedStore 打开（触发迁移）
        let store = try EncryptedStore(
            dbPath: dbPath,
            key: TestDatabaseHelper.makeTestKey()
        )

        // 4. countSamples() 查询 is_sample 列，若列不存在会抛错
        let count = try store.countSamples()
        XCTAssertEqual(count, 0, "迁移后 countSamples 应可用，旧数据 is_sample 默认 0")
    }

    // MARK: - TC-F18-035 迁移保留旧数据不丢失

    func testMigrationPreservesExistingData() throws {
        // 1. 创建新库并保存 2 条数据
        do {
            let store = try EncryptedStore(
                dbPath: dbPath,
                key: TestDatabaseHelper.makeTestKey()
            )
            for index in 0..<2 {
                try store.save(
                    ClipItem.makeText(
                        "item-\(index)",
                        contentType: .article,
                        sourceApp: "com.test",
                        sourceAppName: "Test"
                    )
                )
            }
        }

        // 2. 删除 is_sample 列
        do {
            let connection = try Connection(dbPath.path)
            try connection.run("ALTER TABLE clips DROP COLUMN is_sample")
        }

        // 3. 重新打开触发迁移
        let store = try EncryptedStore(
            dbPath: dbPath,
            key: TestDatabaseHelper.makeTestKey()
        )

        // 4. 验证数据保留
        let loaded = try store.loadAll()
        XCTAssertEqual(loaded.count, 2, "迁移后数据不应丢失")
    }

    // MARK: - TC-F18-036 迁移后旧数据 isSample 默认 false

    func testMigrationDefaultsIsSampleToFalse() throws {
        // 1. 创建新库并保存数据
        do {
            let store = try EncryptedStore(
                dbPath: dbPath,
                key: TestDatabaseHelper.makeTestKey()
            )
            try store.save(
                ClipItem.makeText(
                    "test",
                    contentType: .article,
                    sourceApp: "com.test",
                    sourceAppName: "Test"
                )
            )
        }

        // 2. 删除 is_sample 列
        do {
            let connection = try Connection(dbPath.path)
            try connection.run("ALTER TABLE clips DROP COLUMN is_sample")
        }

        // 3. 重新打开触发迁移
        let store = try EncryptedStore(
            dbPath: dbPath,
            key: TestDatabaseHelper.makeTestKey()
        )

        // 4. 验证旧数据 isSample 默认 false
        let loaded = try store.loadAll()
        XCTAssertTrue(loaded.allSatisfy { $0.isSample == false }, "迁移后旧数据 isSample 应默认 false")
    }

    // MARK: - TC-F18-037 迁移幂等（多次打开不报错不重复添加列）

    func testMigrationIsIdempotent() throws {
        // 1. 创建新库
        do {
            let store = try EncryptedStore(
                dbPath: dbPath,
                key: TestDatabaseHelper.makeTestKey()
            )
            try store.save(
                ClipItem.makeText(
                    "test",
                    contentType: .article,
                    sourceApp: "com.test",
                    sourceAppName: "Test"
                )
            )
        }

        // 2. 删除 is_sample 列
        do {
            let connection = try Connection(dbPath.path)
            try connection.run("ALTER TABLE clips DROP COLUMN is_sample")
        }

        // 3. 第一次迁移
        let store1 = try EncryptedStore(
            dbPath: dbPath,
            key: TestDatabaseHelper.makeTestKey()
        )
        XCTAssertEqual(try store1.countSamples(), 0)

        // 4. 第二次打开（迁移应跳过，is_sample 列已存在）
        let store2 = try EncryptedStore(
            dbPath: dbPath,
            key: TestDatabaseHelper.makeTestKey()
        )
        XCTAssertEqual(try store2.countSamples(), 0, "多次迁移不报错，列不重复添加")

        let loaded = try store2.loadAll()
        XCTAssertEqual(loaded.count, 1, "多次迁移后数据不变")
    }

    // MARK: - TC-F18-038 全新数据库直接含 is_sample 列

    func testNewDatabaseHasIsSampleColumn() throws {
        // 全新 dbPath 创建 EncryptedStore
        let store = try EncryptedStore(
            dbPath: dbPath,
            key: TestDatabaseHelper.makeTestKey()
        )

        // countSamples() 查询 is_sample 列，全新库应直接可用
        let count = try store.countSamples()
        XCTAssertEqual(count, 0, "全新库 countSamples 应返回 0 且无需迁移")

        // 保存 isSample=true 的条目后 countSamples 应为 1
        try store.save(
            ClipItem.makeText(
                "sample",
                contentType: .code,
                sourceApp: "com.test",
                sourceAppName: "Test",
                isSample: true
            )
        )
        XCTAssertEqual(try store.countSamples(), 1, "全新库写入示例后 countSamples 应为 1")
    }
}
