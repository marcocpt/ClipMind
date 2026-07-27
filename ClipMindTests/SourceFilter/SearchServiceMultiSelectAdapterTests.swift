@testable import ClipMind
import XCTest

/// SearchService 集合来源过滤适配测试。
///
/// 验证 search(sourceApps:) 和 searchWithScores(sourceApps:) 的多选过滤行为。
final class SearchServiceMultiSelectAdapterTests: XCTestCase
{
    private var dbPath: URL!
    private var store: EncryptedStore!
    private var embeddingService: LocalEmbeddingService!
    private var searchService: SearchService!

    private static let xcodeApp = "com.apple.xcode"
    private static let vscodeApp = "com.microsoft.vscode"
    private static let safariApp = "com.apple.safari"

    override func setUpWithError() throws
    {
        dbPath = try TestDatabaseHelper.makeTempDBPath()
        store = try EncryptedStore(dbPath: dbPath, key: TestDatabaseHelper.makeTestKey())
        embeddingService = LocalEmbeddingService()
        searchService = SearchService(embeddingService: embeddingService, store: store)

        try saveItem(text: "Swift programming for iOS", sourceApp: Self.xcodeApp)
        try saveItem(text: "Python data analysis", sourceApp: Self.vscodeApp)
        try saveItem(text: "JavaScript web development", sourceApp: Self.xcodeApp)
        try saveItem(text: "Safari browser settings", sourceApp: Self.safariApp)
    }

    override func tearDownWithError() throws
    {
        searchService = nil
        embeddingService = nil
        store = nil
        if let dbPath
        {
            TestDatabaseHelper.cleanup(at: dbPath)
        }
        dbPath = nil
    }

    private func saveItem(text: String, sourceApp: String) throws
    {
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

    // MARK: - 多选集合过滤

    func testSearchWithMultipleSourceAppsReturnsFilteredResults() throws
    {
        let results = try searchService.search(
            query: "programming",
            limit: 10,
            sourceApps: [Self.xcodeApp, Self.vscodeApp]
        )
        XCTAssertGreaterThanOrEqual(results.count, 2, "多选应返回 Xcode 和 VSCode 来源的条目")
        for item in results
        {
            XCTAssertTrue(
                [Self.xcodeApp, Self.vscodeApp].contains(item.sourceApp),
                "所有结果应来自 Xcode 或 VSCode"
            )
        }
    }

    // MARK: - 单选集合过滤

    func testSearchWithSingleSourceAppSetReturnsFilteredResults() throws
    {
        let results = try searchService.search(
            query: "programming",
            limit: 10,
            sourceApps: [Self.xcodeApp]
        )
        XCTAssertFalse(results.isEmpty, "单选集合应返回 Xcode 来源的条目")
        for item in results
        {
            XCTAssertEqual(item.sourceApp, Self.xcodeApp, "单选集合所有结果应来自 Xcode")
        }
    }

    // MARK: - 空集合不过滤

    func testSearchWithEmptySourceAppsReturnsAll() throws
    {
        let results = try searchService.search(
            query: "programming",
            limit: 10,
            sourceApps: []
        )
        XCTAssertGreaterThanOrEqual(results.count, 2, "空集合应等同于不过滤，返回所有来源")
    }

    // MARK: - nil 不过滤

    func testSearchWithNilSourceAppsReturnsAll() throws
    {
        let results = try searchService.search(
            query: "programming",
            limit: 10,
            sourceApps: nil
        )
        XCTAssertGreaterThanOrEqual(results.count, 2, "nil 应等同于不过滤，返回所有来源")
    }

    // MARK: - searchWithScores 多选

    func testSearchWithScoresWithMultipleSourceAppsReturnsFilteredResults() throws
    {
        let results = try searchService.searchWithScores(
            query: "programming",
            limit: 10,
            sourceApps: [Self.xcodeApp, Self.vscodeApp]
        )
        XCTAssertGreaterThanOrEqual(results.count, 2, "searchWithScores 多选应返回匹配来源的条目")
        for result in results
        {
            XCTAssertTrue(
                [Self.xcodeApp, Self.vscodeApp].contains(result.item.sourceApp),
                "searchWithScores 所有结果应来自 Xcode 或 VSCode"
            )
        }
    }

    // MARK: - searchWithScores 空集合不过滤

    func testSearchWithScoresWithEmptySourceAppsReturnsAll() throws
    {
        let results = try searchService.searchWithScores(
            query: "programming",
            limit: 10,
            sourceApps: []
        )
        XCTAssertGreaterThanOrEqual(results.count, 2, "searchWithScores 空集合应返回所有来源")
    }
}
