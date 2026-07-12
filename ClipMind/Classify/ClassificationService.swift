import Foundation

/// 内容分类服务，基于关键词预分类 + 向量匹配实现零样本分类。
///
/// 使用两阶段分类策略：
/// 1. 关键词预分类：对高置信度模式（如 Traceback、待办、URL）直接返回类型
/// 2. 向量匹配：与 11 种 ContentType 的预计算向量进行余弦相似度匹配
///
/// 低于阈值时返回 .other。
final class ClassificationService {
    /// 嵌入服务
    private let embeddingService: LocalEmbeddingService

    /// 11 种内容类型的预计算向量缓存
    private let typeVectors: [ContentType: [Double]]

    /// 分类阈值。最高分低于此值时返回 .other。
    private let threshold: Double

    /// 关键词预分类规则
    private static let keywordRules: [(type: ContentType, patterns: [String])] = [
        (.error, ["traceback", "fatal error", "exc_bad_access", "exc_bad_instruction",
                  "sigabrt", "core dumped", "uncaught exception", "stack trace"]),
        (.link, ["https://", "http://", "www.", ".com/", ".org/", ".io/", "github.com/",
                 "stackoverflow.com", "youtube.com"]),
        (.todo, ["todo:", "- [ ]", "- [x]", "action items:", "task:", "remember to"]),
        (.apiDoc, ["get /api", "post /api", "put /api", "delete /api", "patch /api",
                   "api reference", "api endpoint"]),
        (.code, ["func ", "def ", "class ", "import ", "const ", "let ", "var ",
                 "public ", "private ", "return "])
    ]

    /// 初始化分类服务。
    /// - Parameters:
    ///   - embeddingService: 嵌入服务实例
    ///   - threshold: 分类阈值，默认 0.2
    init(embeddingService: LocalEmbeddingService, threshold: Double = 0.2) {
        self.embeddingService = embeddingService
        self.threshold = threshold
        self.typeVectors = TypeEmbeddings.computeTypeVectors(using: { embeddingService.embed($0) })
    }

    /// 分类文本内容。
    /// - Parameter text: 输入文本
    /// - Returns: 匹配度最高的 ContentType；若文本为空、模型不可用或最高分低于阈值则返回 .other
    func classify(_ text: String) -> ContentType {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .other }

        // 阶段 1：关键词预分类
        if let keywordType = classifyByKeywords(trimmed) {
            LogCategory.classify.debug(
                "Classified text (length=\(trimmed.count)) as \(keywordType.rawValue) by keyword"
            )
            return keywordType
        }

        // 阶段 2：向量匹配
        return classifyByVector(trimmed)
    }

    /// 分类文本内容并返回置信度分数。
    /// - Parameter text: 输入文本
    /// - Returns: (类型, 分数) 元组；若无法分类则返回 (.other, 0.0)
    func classifyWithScore(_ text: String) -> (type: ContentType, score: Double) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return (.other, 0.0) }

        // 阶段 1：关键词预分类（置信度 1.0）
        if let keywordType = classifyByKeywords(trimmed) {
            return (keywordType, 1.0)
        }

        // 阶段 2：向量匹配
        guard let queryVector = embeddingService.embed(trimmed) else { return (.other, 0.0) }

        var bestType: ContentType = .other
        var bestScore: Double = -1.0

        for (type, typeVector) in typeVectors {
            let score = LocalEmbeddingService.cosineSimilarity(queryVector, typeVector)
            if score > bestScore {
                bestScore = score
                bestType = type
            }
        }

        if bestScore < threshold {
            return (.other, bestScore)
        }

        return (bestType, bestScore)
    }

    // MARK: - Private

    /// 关键词预分类
    private func classifyByKeywords(_ text: String) -> ContentType? {
        let lowercased = text.lowercased()

        for rule in Self.keywordRules {
            for pattern in rule.patterns where lowercased.contains(pattern) {
                return rule.type
            }
        }

        return nil
    }

    /// 向量匹配分类
    private func classifyByVector(_ text: String) -> ContentType {
        guard let queryVector = embeddingService.embed(text) else { return .other }

        var bestType: ContentType = .other
        var bestScore: Double = -1.0

        for (type, typeVector) in typeVectors {
            let score = LocalEmbeddingService.cosineSimilarity(queryVector, typeVector)
            if score > bestScore {
                bestScore = score
                bestType = type
            }
        }

        if bestScore < threshold {
            LogCategory.classify.debug(
                "Classified text (length=\(text.count)) as other (score=\(bestScore) < threshold=\(threshold))"
            )
            return .other
        }

        LogCategory.classify.debug("Classified text (length=\(text.count)) as \(bestType.rawValue) score=\(bestScore)")
        return bestType
    }
}
