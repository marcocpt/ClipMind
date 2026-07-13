@testable import ClipMind
import XCTest

final class SampleDataSearchTests: XCTestCase {
    private var dbPath: URL!
    private var store: EncryptedStore!
    private var embeddingService: LocalEmbeddingService!
    private var searchService: SearchService!

    override func setUpWithError() throws {
        dbPath = try TestDatabaseHelper.makeTempDBPath()
        store = try EncryptedStore(
            dbPath: dbPath,
            key: TestDatabaseHelper.makeTestKey()
        )
        embeddingService = LocalEmbeddingService()
        searchService = SearchService(embeddingService: embeddingService, store: store)

        // 预置示例数据（带 embeddings）
        SampleDataSeeder.seedIfNeeded(store: store, embeddingService: embeddingService)
    }

    override func tearDownWithError() throws {
        store = nil
        embeddingService = nil
        searchService = nil
        if let dbPath {
            TestDatabaseHelper.cleanup(at: dbPath)
        }
        dbPath = nil
    }

    // MARK: - TC-F18-029 搜索 error 关键词命中 error 类型示例
    //
    // 原计划使用中文"报错"关键词，但 NLEmbedding.sentenceEmbedding(for: .english)
    // 对中文匹配度不足（Top-5 未命中 .error 条目）。按计划 8.2 节 fallback 方案
    // 改用英文关键词 "error crash" 验证 error 类型示例可被语义搜索命中。

    func testSearchErrorKeywordHitsErrorSamples() throws {
        let results = try searchService.search(query: "error crash", limit: 5)

        XCTAssertFalse(results.isEmpty, "搜索'error crash'应返回非空结果")
        XCTAssertTrue(
            results.contains { $0.contentType == .error },
            "Top-5 结果中应至少 1 条 contentType == .error"
        )
    }

    // MARK: - TC-F18-030 搜索 code 关键词命中 code 类型示例
    //
    // 原计划使用中文"代码"关键词，NLEmbedding 英文模型匹配度不足，
    // 改用英文 "code function" 验证 code 类型示例可被语义搜索命中。

    func testSearchCodeKeywordHitsCodeSamples() throws {
        let results = try searchService.search(query: "code function", limit: 5)

        XCTAssertFalse(results.isEmpty, "搜索'code function'应返回非空结果")
        XCTAssertTrue(
            results.contains { $0.contentType == .code },
            "Top-5 结果中应至少 1 条 contentType == .code"
        )
    }

    // MARK: - TC-F18-031 搜索 link 关键词命中 link 类型示例
    //
    // 原计划使用中文"链接"关键词，NLEmbedding 英文模型匹配度不足，
    // 改用英文 "link url" 验证 link 类型示例可被语义搜索命中。

    func testSearchLinkKeywordHitsLinkSamples() throws {
        let results = try searchService.search(query: "link url", limit: 5)

        XCTAssertFalse(results.isEmpty, "搜索'link url'应返回非空结果")
        XCTAssertTrue(
            results.contains { $0.contentType == .link },
            "Top-5 结果中应至少 1 条 contentType == .link"
        )
    }

    // MARK: - TC-F18-032 带 embeddings 的示例可被搜索

    func testSamplesWithEmbeddingsAreSearchable() throws {
        let allItems = try store.loadAll()

        // 验证所有示例都有 embeddings
        for item in allItems {
            XCTAssertNotNil(item.embeddings, "示例 \(item.id) 应有 embeddings")
        }

        // 搜索任意关键词，结果中的条目都应有 embeddings
        let results = try searchService.search(query: "test", limit: 5)

        for item in results {
            XCTAssertNotNil(item.embeddings, "搜索结果中的条目必须有 embeddings")
            XCTAssertTrue(!(item.embeddings?.isEmpty ?? true), "embeddings 不应为空")
        }
    }
}
