@testable import ClipMind
import XCTest

/// 来源 App 过滤测试。
///
/// 验证 AC-12（来源 App 过滤）：搜索时可按 sourceApp 过滤结果。
final class SourceFilterTests: XCTestCase {
    private var dbPath: URL!
    private var store: EncryptedStore!
    private var embeddingService: LocalEmbeddingService!
    private var searchService: SearchService!

    /// 测试样本：3 条文本，分属 2 个 sourceApp
    private static let xcodeApp = "com.apple.xcode"
    private static let vscodeApp = "com.microsoft.vscode"

    override func setUpWithError() throws {
        dbPath = try TestDatabaseHelper.makeTempDBPath()
        store = try EncryptedStore(dbPath: dbPath, key: TestDatabaseHelper.makeTestKey())
        embeddingService = LocalEmbeddingService()
        searchService = SearchService(embeddingService: embeddingService, store: store)

        try saveItem(text: "Swift programming for iOS", sourceApp: Self.xcodeApp)
        try saveItem(text: "Python data analysis", sourceApp: Self.vscodeApp)
        try saveItem(text: "JavaScript web development", sourceApp: Self.xcodeApp)
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
    private func saveItem(text: String, sourceApp: String) throws {
        let embeddings = embeddingService.embed(text)?.map { Float($0) }
        let item = ClipItem(
            id: UUID(),
            content: .text(text),
            contentType: .article,
            sourceApp: sourceApp,
            sourceAppName: sourceApp,
            timestamp: Date(),
            summary: nil,
            translation: nil,
            rewrite: nil,
            todos: nil,
            embeddings: embeddings
        )
        try store.save(item)
    }

    // MARK: - AC-12: 来源 App 过滤

    func testSearchWithMatchingSourceAppReturnsFilteredResults() throws {
        let results = try searchService.search(
            query: "programming", limit: 5, sourceApp: Self.xcodeApp
        )
        XCTAssertFalse(results.isEmpty, "应返回 Xcode 来源的条目")
        for item in results {
            XCTAssertEqual(item.sourceApp, Self.xcodeApp, "所有结果应来自 Xcode")
        }
    }

    func testSearchWithNonMatchingSourceAppReturnsEmpty() throws {
        let results = try searchService.search(
            query: "programming", limit: 5, sourceApp: "com.nonexistent.app"
        )
        XCTAssertTrue(results.isEmpty, "不匹配的 sourceApp 应返回空结果")
    }

    func testSearchWithoutSourceAppReturnsAll() throws {
        let results = try searchService.search(query: "programming", limit: 10)
        XCTAssertGreaterThanOrEqual(results.count, 2, "无过滤应返回多个来源的条目")
    }

    func testSearchWithScoresRespectsSourceAppFilter() throws {
        let results = try searchService.searchWithScores(
            query: "programming", limit: 5, sourceApp: Self.xcodeApp
        )
        XCTAssertFalse(results.isEmpty, "searchWithScores 也应支持 sourceApp 过滤")
        for result in results {
            XCTAssertEqual(
                result.item.sourceApp, Self.xcodeApp,
                "searchWithScores 所有结果应来自 Xcode"
            )
        }
    }

    func testSearchWithScoresWithoutFilterReturnsAll() throws {
        let results = try searchService.searchWithScores(query: "programming", limit: 10)
        XCTAssertGreaterThanOrEqual(results.count, 2, "无过滤应返回多个来源的条目")
    }
}
