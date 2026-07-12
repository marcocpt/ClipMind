import Foundation

/// 语义搜索服务。
///
/// 使用 LocalEmbeddingService 生成查询向量，通过 EncryptedStore 进行余弦相似度搜索。
/// 支持跨语言搜索（NLEmbedding 向量空间对齐）和来源 App 过滤。
final class SearchService {
    /// 嵌入服务
    private let embeddingService: LocalEmbeddingService

    /// 加密存储
    private let store: EncryptedStore

    /// 初始化搜索服务。
    /// - Parameters:
    ///   - embeddingService: 嵌入服务实例
    ///   - store: 加密存储实例
    init(embeddingService: LocalEmbeddingService, store: EncryptedStore) {
        self.embeddingService = embeddingService
        self.store = store
    }

    /// 语义搜索。
    /// - Parameters:
    ///   - query: 自然语言查询文本
    ///   - limit: 返回结果数量，默认 5
    ///   - sourceApp: 可选来源 App 过滤（bundle ID）
    /// - Returns: 按相似度降序排列的 ClipItem 数组
    /// - Throws: EncryptedStore 读取错误
    func search(query: String, limit: Int = 5, sourceApp: String? = nil) throws -> [ClipItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        guard let queryVector = embeddingService.embed(trimmed) else {
            LogCategory.search.warning("Failed to generate embedding for query: \(trimmed)")
            return []
        }

        let floatQuery = queryVector.map { Float($0) }
        let results = try store.search(query: floatQuery, limit: limit, sourceApp: sourceApp)

        LogCategory.search.info("Search '\(trimmed)' returned \(results.count) results")
        return results
    }

    /// 搜索并返回带分数的结果。
    /// - Parameters:
    ///   - query: 自然语言查询文本
    ///   - limit: 返回结果数量，默认 5
    ///   - sourceApp: 可选来源 App 过滤（bundle ID）
    /// - Returns: 按相似度降序排列的 (ClipItem, 分数) 数组
    /// - Throws: EncryptedStore 读取错误
    func searchWithScores(
        query: String,
        limit: Int = 5,
        sourceApp: String? = nil
    ) throws -> [(item: ClipItem, score: Double)] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        guard let queryVector = embeddingService.embed(trimmed) else {
            LogCategory.search.warning("Failed to generate embedding for query: \(trimmed)")
            return []
        }

        // 加载所有条目并计算相似度
        let allItems = try store.loadAll()
        var filtered = allItems
        if let sourceApp = sourceApp {
            filtered = allItems.filter { $0.sourceApp == sourceApp }
        }

        var scored: [(item: ClipItem, score: Double)] = []
        for item in filtered {
            guard let itemEmbeddings = item.embeddings, !itemEmbeddings.isEmpty else { continue }
            let itemVector = itemEmbeddings.map { Double($0) }
            guard itemVector.count == queryVector.count else { continue }

            let score = LocalEmbeddingService.cosineSimilarity(queryVector, itemVector)
            scored.append((item: item, score: score))
        }

        let results = scored.sorted { $0.score > $1.score }.prefix(limit).map { $0 }
        LogCategory.search.info("Search '\(trimmed)' returned \(results.count) results with scores")
        return Array(results)
    }
}
