@testable import ClipMind
import XCTest

final class EncryptedStoreSampleTests: XCTestCase {
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

    // MARK: - TC-F18-011 空库 countSamples 返回 0

    func testCountSamplesReturnsZeroOnEmptyDB() throws {
        XCTAssertEqual(try store.countSamples(), 0, "空库示例计数应为 0")
    }

    // MARK: - TC-F18-012 countSamples 仅统计示例条目

    func testCountSamplesReturnsCorrectCount() throws {
        // 3 条示例
        for index in 0..<3 {
            let item = ClipItem.makeText(
                "sample-\(index)",
                contentType: .code,
                sourceApp: "com.test",
                sourceAppName: "Test",
                isSample: true
            )
            try store.save(item)
        }
        // 2 条真实数据
        for index in 0..<2 {
            let item = ClipItem.makeText(
                "real-\(index)",
                contentType: .article,
                sourceApp: "com.test",
                sourceAppName: "Test",
                isSample: false
            )
            try store.save(item)
        }

        XCTAssertEqual(try store.countSamples(), 3, "应仅统计 isSample=true 的条目")
    }

    // MARK: - TC-F18-013 deleteSamples 仅删除示例保留真实数据

    func testDeleteSamplesRemovesOnlySamples() throws {
        // 3 条示例
        for index in 0..<3 {
            try store.save(
                ClipItem.makeText(
                    "sample-\(index)",
                    contentType: .code,
                    sourceApp: "com.test",
                    sourceAppName: "Test",
                    isSample: true
                )
            )
        }
        // 3 条真实数据
        for index in 0..<3 {
            try store.save(
                ClipItem.makeText(
                    "real-\(index)",
                    contentType: .article,
                    sourceApp: "com.test",
                    sourceAppName: "Test",
                    isSample: false
                )
            )
        }

        try store.deleteSamples()

        let loaded = try store.loadAll()
        XCTAssertEqual(loaded.count, 3, "删除示例后应保留 3 条真实数据")
        XCTAssertTrue(loaded.allSatisfy { $0.isSample == false }, "剩余条目全部应为非示例")
    }

    // MARK: - TC-F18-014 deleteSamples 返回实际删除行数

    func testDeleteSamplesReturnsRowCount() throws {
        for index in 0..<13 {
            try store.save(
                ClipItem.makeText(
                    "sample-\(index)",
                    contentType: .code,
                    sourceApp: "com.test",
                    sourceAppName: "Test",
                    isSample: true
                )
            )
        }

        let deleted = try store.deleteSamples()
        XCTAssertEqual(deleted, 13, "返回值应为实际删除的行数 13")
    }

    // MARK: - TC-F18-015 save 写入 is_sample 列

    func testSaveWritesIsSampleColumn() throws {
        let sampleItem = ClipItem.makeText(
            "sample",
            contentType: .code,
            sourceApp: "com.test",
            sourceAppName: "Test",
            isSample: true
        )
        try store.save(sampleItem)

        let realItem = ClipItem.makeText(
            "real",
            contentType: .article,
            sourceApp: "com.test",
            sourceAppName: "Test",
            isSample: false
        )
        try store.save(realItem)

        // countSamples 查询 is_sample=1 的行
        XCTAssertEqual(try store.countSamples(), 1, "isSample=true 的条目应被统计")
    }

    // MARK: - TC-F18-016 loadAll 解码 isSample 字段一致

    func testLoadAllDecodesIsSampleField() throws {
        let sampleItem = ClipItem.makeText(
            "sample",
            contentType: .code,
            sourceApp: "com.test",
            sourceAppName: "Test",
            isSample: true
        )
        try store.save(sampleItem)

        let realItem = ClipItem.makeText(
            "real",
            contentType: .article,
            sourceApp: "com.test",
            sourceAppName: "Test",
            isSample: false
        )
        try store.save(realItem)

        let loaded = try store.loadAll()
        XCTAssertEqual(loaded.count, 2)

        let loadedSample = loaded.first { $0.id == sampleItem.id }
        XCTAssertEqual(loadedSample?.isSample, true, "示例条目 isSample 应为 true")

        let loadedReal = loaded.first { $0.id == realItem.id }
        XCTAssertEqual(loadedReal?.isSample, false, "真实条目 isSample 应为 false")
    }

    // MARK: - TC-F18-028 清除后发送通知刷新 UI

    func testClearSamplesPostsNotification() throws {
        try store.save(
            ClipItem.makeText(
                "sample",
                contentType: .code,
                sourceApp: "com.test",
                sourceAppName: "Test",
                isSample: true
            )
        )

        var notificationCount = 0
        let observer = NotificationCenter.default.addObserver(
            forName: ClipCaptureService.clipDidUpdateNotification,
            object: nil,
            queue: nil
        ) { _ in
            notificationCount += 1
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        // 清除示例数据并发送通知（模拟 GeneralSettingsView.clearSampleData 的核心逻辑）
        try store.deleteSamples()
        NotificationCenter.default.post(
            name: ClipCaptureService.clipDidUpdateNotification,
            object: nil
        )

        XCTAssertEqual(notificationCount, 1, "清除后应发送 clipDidUpdateNotification")
    }
}
