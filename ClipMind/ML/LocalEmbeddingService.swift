import Foundation
import NaturalLanguage

/// 本地嵌入服务，基于 macOS NaturalLanguage 框架的 NLEmbedding。
///
/// 提供文本嵌入向量和内容分类功能：
/// - embed(_:): 生成文本的向量表示
/// - classify(_:): 通过向量匹配识别 11 种内容类型
/// - cosineSimilarity(_:_:): 计算两个向量的余弦相似度
///
/// 使用 macOS 13.0+ 内置的 NLEmbedding，无需下载额外模型。
final class LocalEmbeddingService {
    /// NLEmbedding 实例（英文模型，对中英文均有支持）
    private let embedding: NLEmbedding?

    /// 11 种内容类型的预计算向量缓存
    private lazy var typeVectors: [ContentType: [Double]] = {
        var cache: [ContentType: [Double]] = [:]
        for (type, texts) in Self.typeDescriptions {
            let vectors = texts.compactMap { embed($0) }
            guard !vectors.isEmpty else { continue }
            cache[type] = averageVector(vectors)
        }
        return cache
    }()

    /// 初始化嵌入服务
    init() {
        self.embedding = NLEmbedding.sentenceEmbedding(for: .english)
        if embedding == nil {
            LogCategory.classify.warning("NLEmbedding.sentenceEmbedding(for: .english) returned nil")
        }
    }

    // MARK: - Public

    /// 生成文本的嵌入向量
    /// - Parameter text: 输入文本
    /// - Returns: 嵌入向量数组，若文本为空或模型不可用则返回 nil
    func embed(_ text: String) -> [Double]? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return embedding?.vector(for: trimmed)
    }

    /// 分类文本内容
    /// - Parameter text: 输入文本
    /// - Returns: 匹配度最高的 ContentType，若无法分类则返回 .other
    func classify(_ text: String) -> ContentType {
        guard let queryVector = embed(text) else { return .other }

        var bestType: ContentType = .other
        var bestScore: Double = -1.0

        for (type, typeVector) in typeVectors {
            let score = Self.cosineSimilarity(queryVector, typeVector)
            if score > bestScore {
                bestScore = score
                bestType = type
            }
        }

        LogCategory.classify.debug("Classified text (length=\(text.count)) as \(bestType.rawValue) score=\(bestScore)")
        return bestType
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

    // MARK: - Private

    /// 计算多个向量的平均向量
    private func averageVector(_ vectors: [[Double]]) -> [Double] {
        guard let firstVector = vectors.first else { return [] }
        let count = vectors.count
        var result = [Double](repeating: 0.0, count: firstVector.count)

        for vector in vectors {
            for index in 0..<min(vector.count, result.count) {
                result[index] += vector[index]
            }
        }

        for index in 0..<result.count {
            result[index] /= Double(count)
        }

        return result
    }

    /// 11 种内容类型及其代表文本
    /// 用于生成类型向量，实现零样本分类
    private static let typeDescriptions: [(ContentType, [String])] = [
        (.code, [
            "func viewDidLoad() { super.viewDidLoad() }",
            "def calculate(x, y): return x + y",
            "import React from 'react'; const App = () => <div>Hello</div>;",
            "class Solution: def twoSum(self, nums, target):",
            "const promise = new Promise((resolve, reject) => {"
        ]),
        (.link, [
            "https://www.github.com/user/repo",
            "https://stackoverflow.com/questions/123456/how-to-fix-bug",
            "https://developer.apple.com/documentation/swift",
            "https://www.google.com/search?q=swift",
            "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
        ]),
        (.error, [
            "Thread 1: Fatal error: Unexpectedly found nil while unwrapping",
            "Traceback (most recent call last): File '<stdin>', line 1, in <module>",
            "Error: Cannot find module 'express'",
            "EXC_BAD_INSTRUCTION (code=EXC_I386_INVOP, subcode=0x0)",
            "TypeError: 'NoneType' object is not iterable"
        ]),
        (.article, [
            "The future of artificial intelligence in everyday applications",
            "How to improve your productivity with time management techniques",
            "Understanding the basics of machine learning and neural networks",
            "A comprehensive guide to modern web development",
            "The impact of social media on modern communication"
        ]),
        (.todo, [
            "TODO: Fix the login bug before Friday",
            "- [ ] Buy groceries: milk, bread, eggs",
            "Task: Complete the quarterly report by end of month",
            "Remember to call the dentist to schedule appointment",
            "Action items: Review PR, Update docs, Deploy to staging"
        ]),
        (.meeting, [
            "Meeting notes: Discussed Q4 roadmap and team assignments",
            "Standup: Yesterday finished API integration, today working on tests",
            "Conference call summary: Client approved the design mockups",
            "Sprint planning: Committed to 5 user stories for next sprint",
            "Weekly sync: Marketing team needs new landing page by Monday"
        ]),
        (.translation, [
            "Hello World -> Bonjour le Monde",
            "Good morning -> Buenos dias",
            "Translate: The quick brown fox jumps over the lazy dog",
            "English to Chinese: Artificial Intelligence -> 人工智能",
            "Japanese: こんにちは世界 (Hello World)"
        ]),
        (.requirement, [
            "User Story: As a user, I want to login with email so that I can access my account",
            "Requirement: The system shall support up to 1000 concurrent users",
            "Acceptance Criteria: Given valid credentials, when user clicks login, then redirect to dashboard",
            "Feature: Password reset via email link with 24-hour expiry",
            "PRD: Mobile app must support iOS 14+ and Android 10+"
        ]),
        (.apiDoc, [
            "GET /api/v1/users - Returns list of users. Parameters: limit, offset",
            "POST /api/v1/auth/login - Authenticate user. Body: {email, password}",
            "API Reference: response format {status: 200, data: {}, error: null}",
            "DELETE /api/v1/items/{id} - Delete item by ID. Returns 204 No Content",
            "PUT /api/v1/profile - Update user profile. Required fields: name, email"
        ]),
        (.englishDoc, [
            "The Quick Brown Fox Jumps Over The Lazy Dog",
            "Documentation: How to configure the application settings",
            "README: This project demonstrates a clipboard manager for macOS",
            "Guide: Setting up your development environment in five easy steps",
            "Tutorial: Learn how to build a REST API with Node.js and Express"
        ]),
        (.other, [
            "Random text that doesn't fit any specific category",
            "12345 67890 abcdef",
            "Lorem ipsum dolor sit amet consectetur adipiscing elit",
            "Mixed content with numbers 123 and symbols @#$%",
            "Some miscellaneous notes and observations"
        ])
    ]
}
