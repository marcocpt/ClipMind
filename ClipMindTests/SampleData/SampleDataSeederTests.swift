@testable import ClipMind
import XCTest

final class SampleDataSeederTests: XCTestCase {
    private var dbPath: URL!
    private var store: EncryptedStore!
    private var embeddingService: LocalEmbeddingService!

    override func setUpWithError() throws {
        dbPath = try TestDatabaseHelper.makeTempDBPath()
        store = try EncryptedStore(
            dbPath: dbPath,
            key: TestDatabaseHelper.makeTestKey()
        )
        embeddingService = LocalEmbeddingService()
    }

    override func tearDownWithError() throws {
        store = nil
        embeddingService = nil
        if let dbPath {
            TestDatabaseHelper.cleanup(at: dbPath)
        }
        dbPath = nil
    }

    // MARK: - TC-F18-001（数据部分）sampleClipsForSeeding 数量 ≥ 12

    func testSampleClipsForSeedingCount() {
        let samples = ClipTestData.sampleClipsForSeeding

        XCTAssertGreaterThanOrEqual(samples.count, 12, "示例数据应至少 12 条")
        XCTAssertEqual(samples.count, 13, "示例数据精确为 13 条")
    }

    // MARK: - TC-F18-002（数据部分）sampleClipsForSeeding 覆盖 11 种 ContentType

    func testSampleClipsCoverAllContentTypes() {
        let samples = ClipTestData.sampleClipsForSeeding
        let types = Set(samples.map(\.contentType))

        XCTAssertEqual(types.count, 11, "应覆盖全部 11 种 ContentType")
        XCTAssertTrue(types.contains(.code), "缺少 code 类型")
        XCTAssertTrue(types.contains(.link), "缺少 link 类型")
        XCTAssertTrue(types.contains(.error), "缺少 error 类型")
        XCTAssertTrue(types.contains(.article), "缺少 article 类型")
        XCTAssertTrue(types.contains(.todo), "缺少 todo 类型")
        XCTAssertTrue(types.contains(.meeting), "缺少 meeting 类型")
        XCTAssertTrue(types.contains(.translation), "缺少 translation 类型")
        XCTAssertTrue(types.contains(.requirement), "缺少 requirement 类型")
        XCTAssertTrue(types.contains(.apiDoc), "缺少 apiDoc 类型")
        XCTAssertTrue(types.contains(.englishDoc), "缺少 englishDoc 类型")
        XCTAssertTrue(types.contains(.other), "缺少 other 类型")
    }

    // MARK: - TC-F18-004（数据部分）每条示例 isSample=true

    func testSampleClipsHaveIsSampleTrue() {
        let samples = ClipTestData.sampleClipsForSeeding

        XCTAssertTrue(samples.allSatisfy { $0.isSample }, "每条示例数据 isSample 应为 true")
    }

    // MARK: - TC-F18-005（数据部分）时间戳递减分布

    func testSampleClipsTimestampsDescending() {
        let samples = ClipTestData.sampleClipsForSeeding

        // sampleClipsForSeeding 中时间戳应递减（第 1 条最近，第 13 条最远）
        for index in 0..<(samples.count - 1) {
            XCTAssertGreaterThanOrEqual(
                samples[index].timestamp,
                samples[index + 1].timestamp,
                "第 \(index + 1) 条时间戳应 >= 第 \(index + 2) 条"
            )
        }

        // 验证时间范围：最早的一条不超过 5 小时前
        let now = Date()
        let oldest = samples.last!.timestamp
        let maxAge: TimeInterval = 5 * 3600  // 5 小时
        XCTAssertLessThan(now.timeIntervalSince(oldest), maxAge, "最早示例不应超过 5 小时前")
    }
}
