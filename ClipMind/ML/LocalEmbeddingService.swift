import Foundation
import NaturalLanguage

/// 本地嵌入服务，基于 macOS NaturalLanguage 框架的 NLEmbedding。
///
/// 提供文本嵌入向量和余弦相似度计算：
/// - embed(_:): 生成文本的向量表示
/// - cosineSimilarity(_:_:): 计算两个向量的余弦相似度
///
/// 使用 macOS 13.0+ 内置的 NLEmbedding，无需下载额外模型。
final class LocalEmbeddingService {
    /// NLEmbedding 实例（英文模型，对中英文均有支持）
    private let embedding: NLEmbedding?

    /// 初始化嵌入服务
    init() {
        self.embedding = NLEmbedding.sentenceEmbedding(for: .english)
        if embedding == nil {
            LogCategory.classify.warning("NLEmbedding.sentenceEmbedding(for: .english) returned nil")
        }
    }

    /// 生成文本的嵌入向量
    /// - Parameter text: 输入文本
    /// - Returns: 嵌入向量数组，若文本为空或模型不可用则返回 nil
    func embed(_ text: String) -> [Double]? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return embedding?.vector(for: trimmed)
    }

    /// 计算两个向量的余弦相似度
    /// - Parameters:
    ///   - vectorA: 向量 A
    ///   - vectorB: 向量 B
    /// - Returns: 余弦相似度 [-1, 1]，若维度不匹配或零向量则返回 0
    static func cosineSimilarity(_ vectorA: [Double], _ vectorB: [Double]) -> Double {
        guard vectorA.count == vectorB.count, !vectorA.isEmpty else { return 0.0 }

        var dotProduct: Double = 0.0
        var normA: Double = 0.0
        var normB: Double = 0.0

        for index in 0..<vectorA.count {
            dotProduct += vectorA[index] * vectorB[index]
            normA += vectorA[index] * vectorA[index]
            normB += vectorB[index] * vectorB[index]
        }

        let denominator = sqrt(normA) * sqrt(normB)
        guard denominator > 0 else { return 0.0 }
        return dotProduct / denominator
    }
}
