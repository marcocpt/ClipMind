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

    // MARK: - TC-F18-001 空库注入示例数据

    func testSeedIfNeededInjectsSamples() throws {
        SampleDataSeeder.seedIfNeeded(store: store, embeddingService: embeddingService)

        XCTAssertEqual(try store.countSamples(), 13, "注入后示例计数应为 13")
        XCTAssertEqual(try store.loadAll().count, 13, "注入后总条目应为 13")
    }

    // MARK: - TC-F18-006 二次调用不重复注入

    func testSeedIfNeededIsIdempotent() throws {
        SampleDataSeeder.seedIfNeeded(store: store, embeddingService: embeddingService)
        let firstCount = try store.countSamples()

        // 再次调用
        SampleDataSeeder.seedIfNeeded(store: store, embeddingService: embeddingService)
        let secondCount = try store.countSamples()

        XCTAssertEqual(firstCount, secondCount, "二次调用 countSamples 不应变化")
        XCTAssertEqual(secondCount, 13, "仍为 13 条")
    }

    // MARK: - TC-F18-007 注入完成发送通知

    func testSeedIfNeededSendsNotification() throws {
        var notificationCount = 0
        let observer = NotificationCenter.default.addObserver(
            forName: ClipCaptureService.clipDidUpdateNotification,
            object: nil,
            queue: nil
        ) { _ in
            notificationCount += 1
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        SampleDataSeeder.seedIfNeeded(store: store, embeddingService: embeddingService)

        XCTAssertEqual(notificationCount, 1, "注入完成后应发送恰好 1 次通知")
    }

    // MARK: - TC-F18-003 每条示例带非空 embeddings

    func testSeededSamplesHaveEmbeddings() throws {
        SampleDataSeeder.seedIfNeeded(store: store, embeddingService: embeddingService)

        let loaded = try store.loadAll()
        for item in loaded {
            XCTAssertNotNil(item.embeddings, "示例 \(item.id) 的 embeddings 不应为 nil")
            XCTAssertTrue(
                !(item.embeddings?.isEmpty ?? true),
                "示例 \(item.id) 的 embeddings 不应为空数组"
            )
        }
    }

    // MARK: - TC-F18-002 注入示例覆盖全部 11 种 ContentType

    func testSeededSamplesCoverAllContentTypes() throws {
        SampleDataSeeder.seedIfNeeded(store: store, embeddingService: embeddingService)

        let loaded = try store.loadAll()
        let types = Set(loaded.map(\.contentType))

        XCTAssertEqual(types.count, 11, "注入后应覆盖全部 11 种 ContentType")
    }

    // MARK: - TC-F18-004 注入后每条 isSample=true

    func testSeededSamplesHaveIsSampleTrue() throws {
        SampleDataSeeder.seedIfNeeded(store: store, embeddingService: embeddingService)

        let loaded = try store.loadAll()
        XCTAssertTrue(loaded.allSatisfy { $0.isSample }, "注入的每条 isSample 应为 true")
    }

    // MARK: - TC-F18-008 embeddings 从 [Double] 转 [Float]

    func testEmbeddingsDoubleToFloatConversion() throws {
        SampleDataSeeder.seedIfNeeded(store: store, embeddingService: embeddingService)

        let loaded = try store.loadAll()
        // 取第一条带 embeddings 的条目
        let firstWithEmb = loaded.first { $0.embeddings != nil }
        XCTAssertNotNil(firstWithEmb, "应至少有一条带 embeddings 的示例")

        // embeddings 类型应为 [Float]（与 LocalEmbeddingService.embed 返回的 [Double] 经 map { Float($0) } 转换一致）
        // 注意：metatype 不能用 XCTAssertEqual 比较（不满足 Equatable），改用 == 操作符
        let embeddings = firstWithEmb!.embeddings!
        XCTAssertTrue(type(of: embeddings) == [Float].self, "embeddings 类型应为 [Float]")

        // 验证维度与 LocalEmbeddingService 直接计算结果一致
        if case .text(let text) = firstWithEmb!.content {
            let doubleEmb = embeddingService.embed(text)
            XCTAssertNotNil(doubleEmb, "LocalEmbeddingService 对非空文本应返回非 nil embeddings")
            XCTAssertEqual(embeddings.count, doubleEmb?.count, "维度应与 [Double] 一致")
        } else {
            XCTFail("示例内容应为 .text 类型")
        }
    }

    // MARK: - TC-F18-039 注入后真实复制与示例共存

    func testSamplesCoexistWithRealData() throws {
        SampleDataSeeder.seedIfNeeded(store: store, embeddingService: embeddingService)

        // 保存 1 条真实数据
        let realItem = ClipItem.makeText(
            "真实复制内容",
            contentType: .other,
            sourceApp: "com.test.real",
            sourceAppName: "RealApp",
            isSample: false
        )
        try store.save(realItem)

        let loaded = try store.loadAll()
        XCTAssertEqual(loaded.count, 14, "应为 13 示例 + 1 真实")

        let realLoaded = loaded.first { $0.id == realItem.id }
        XCTAssertEqual(realLoaded?.isSample, false, "真实条目 isSample 应为 false")
    }

    // MARK: - TC-F18-021 completeOnboarding 触发注入

    /// 验证 completeOnboarding 等价逻辑（直接调用 seedIfNeeded）后 store 中有示例数据。
    ///
    /// completeOnboarding 内部通过 DispatchQueue.global 异步 dispatch 调用 seedIfNeeded，
    /// 此处直接同步调用 seedIfNeeded 验证其本身能正确注入数据。
    /// seedIfNeeded 是同步方法（内部不做异步 dispatch），因此无需 expectation 轮询。
    func testCompleteOnboardingTriggersSeeding() throws {
        let beforeCount = try store.countSamples()
        XCTAssertEqual(beforeCount, 0, "注入前示例数应为 0")

        // 调用 completeOnboarding 等价逻辑：直接调用 seedIfNeeded
        // （completeOnboarding 内部异步 dispatch 调用 seedIfNeeded，
        //   此处验证 seedIfNeeded 本身能正确注入数据）
        SampleDataSeeder.seedIfNeeded(store: store, embeddingService: embeddingService)

        XCTAssertGreaterThanOrEqual(
            try store.countSamples(), 10,
            "completeOnboarding 触发注入后示例数应 >= 10"
        )
    }
}
