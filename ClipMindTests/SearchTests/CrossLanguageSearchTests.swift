@testable import ClipMind
import XCTest

/// 跨语言搜索测试。
///
/// 验证 AC-11（跨语言搜索）：中英文互相查询应能找到语义相近的条目。
/// NLEmbedding 英文模型对中文有一定支持，相似度可能不如同语言高。
final class CrossLanguageSearchTests: XCTestCase {
    private var dbPath: URL!
    private var store: EncryptedStore!
    private var embeddingService: LocalEmbeddingService!
    private var searchService: SearchService!

    override func setUpWithError() throws {
        dbPath = try TestDatabaseHelper.makeTempDBPath()
        store = try EncryptedStore(dbPath: dbPath, key: TestDatabaseHelper.makeTestKey())
        embeddingService = LocalEmbeddingService()
        searchService = SearchService(embeddingService: embeddingService, store: store)
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
    private func saveItem(text: String) throws {
        let embeddings = embeddingService.embed(text)?.map { Float($0) }
        let item = ClipItem(
            id: UUID(),
            content: .text(text),
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
    }

    // MARK: - 同语言基线

    func testSearchEnglishQueryFindsEnglishItem() throws {
        try saveItem(text: "Machine learning is a subset of artificial intelligence")
        let results = try searchService.search(query: "machine learning", limit: 5)
        XCTAssertFalse(results.isEmpty, "英文查询应能找到英文条目")
    }

    // MARK: - 跨语言（AC-11）

    func testSearchEnglishQueryFindsChineseItem() throws {
        try saveItem(text: "机器学习是人工智能的一个子领域，通过数据训练模型")
        let results = try searchService.search(
            query: "machine learning artificial intelligence", limit: 5
        )
        XCTAssertFalse(results.isEmpty, "英文查询应能找到语义相近的中文条目")
    }

    func testSearchChineseQueryFindsEnglishItem() throws {
        try saveItem(text: "Deep learning neural networks for image recognition")
        let results = try searchService.search(query: "深度学习 神经网络 图像识别", limit: 5)
        XCTAssertFalse(results.isEmpty, "中文查询应能找到语义相近的英文条目")
    }

    func testSearchMixedLanguageQueryReturnsResults() throws {
        try saveItem(text: "Natural language processing with transformer models")
        let results = try searchService.search(query: "自然语言 处理 transformer", limit: 5)
        XCTAssertFalse(results.isEmpty, "混合语言查询应能返回结果")
    }
}
