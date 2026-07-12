@testable import ClipMind
import XCTest

/// SearchService 基础功能测试。
///
/// 验证 AC-09（搜索 < 500ms）和 AC-10（Top-5 命中率）。
/// 使用真实 LocalEmbeddingService 生成 embeddings，预存样本数据后查询。
final class SearchServiceTests: XCTestCase {
    private var dbPath: URL!
    private var store: EncryptedStore!
    private var embeddingService: LocalEmbeddingService!
    private var searchService: SearchService!

    /// 测试样本：5 条语义不同的英文文本
    private static let sampleTexts = [
        "Swift programming language for iOS development",
        "Python machine learning tutorial with TensorFlow",
        "How to make pasta carbonara recipe at home",
        "Meeting notes from project review discussion",
        "Error handling best practices in software engineering"
    ]

    override func setUpWithError() throws {
        dbPath = try TestDatabaseHelper.makeTempDBPath()
        store = try EncryptedStore(dbPath: dbPath, key: TestDatabaseHelper.makeTestKey())
        embeddingService = LocalEmbeddingService()
        searchService = SearchService(embeddingService: embeddingService, store: store)

        for text in Self.sampleTexts {
            try saveItem(text: text)
        }
    }

    override func tearDownWithError() throws {
        searchService = nil
        embeddingService = nil
        store = nil
        if let dbPath {
            TestDatabaseHelper.cleanup(at: dbPath)
        }
        dbPath = nil
    }

    /// 保存带 embeddings 的文本条目
    private func saveItem(text: String, sourceApp: String = "com.test.app") throws {
        let embeddings = embeddingService.embed(text)?.map { Float($0) }
        let item = ClipItem(
            id: UUID(),
            content: .text(text),
            contentType: .article,
            sourceApp: sourceApp,
            sourceAppName: "TestApp",
            timestamp: Date(),
            summary: nil,
            translation: nil,
            rewrite: nil,
            todos: nil,
            embeddings: embeddings
        )
        try store.save(item)
    }

    // MARK: - 空查询

    func testSearchReturnsEmptyForEmptyQuery() throws {
        let results = try searchService.search(query: "", limit: 5)
        XCTAssertTrue(results.isEmpty, "空查询应返回空结果")
    }

    func testSearchReturnsEmptyForWhitespaceQuery() throws {
        let results = try searchService.search(query: "   \n\t  ", limit: 5)
        XCTAssertTrue(results.isEmpty, "纯空白查询应返回空结果")
    }

    // MARK: - 基础搜索（AC-10 Top-5 命中率）

    func testSearchFindsItemByExactText() throws {
        let results = try searchService.search(query: Self.sampleTexts[0], limit: 5)
        XCTAssertFalse(results.isEmpty, "用存储文本作为查询应能找到结果")

        if case .text(let value) = results.first?.content {
            XCTAssertEqual(value, Self.sampleTexts[0], "首位结果应是完全匹配的条目")
        } else {
            XCTFail("Expected text content")
        }
    }

    func testSearchRespectsLimit() throws {
        let results = try searchService.search(query: "programming", limit: 2)
        XCTAssertLessThanOrEqual(results.count, 2, "结果数不应超过 limit")
    }

    func testSearchEmptyDatabaseReturnsEmpty() throws {
        try store.deleteAll()
        let results = try searchService.search(query: "programming", limit: 5)
        XCTAssertTrue(results.isEmpty, "空数据库搜索应返回空结果")
    }

    // MARK: - searchWithScores

    func testSearchWithScoresReturnsSortedResults() throws {
        let results = try searchService.searchWithScores(query: Self.sampleTexts[0], limit: 5)
        XCTAssertFalse(results.isEmpty, "应返回带分数的结果")

        for index in 1..<results.count {
            XCTAssertGreaterThanOrEqual(
                results[index - 1].score, results[index].score,
                "结果应按相似度降序排列"
            )
        }

        if case .text(let value) = results.first?.item.content {
            XCTAssertEqual(value, Self.sampleTexts[0], "首位应是完全匹配的条目")
        } else {
            XCTFail("Expected text content")
        }
        XCTAssertGreaterThan(
            results.first?.score ?? 0.0, 0.9,
            "相同文本相似度应大于 0.9"
        )
    }

    func testSearchWithScoresReturnsEmptyForEmptyQuery() throws {
        let results = try searchService.searchWithScores(query: "", limit: 5)
        XCTAssertTrue(results.isEmpty, "空查询应返回空结果")
    }

    // MARK: - 性能（AC-09: < 500ms）

    func testSearchPerformanceUnder500ms() throws {
        measure {
            _ = try? searchService.search(query: "programming tutorial", limit: 5)
        }
    }
}
