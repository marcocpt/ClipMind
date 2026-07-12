import Foundation

/// 11 种内容类型的嵌入向量管理。
///
/// 负责定义每种 ContentType 的代表性文本，并基于嵌入服务预计算类型向量缓存，
/// 供 ClassificationService 进行零样本分类。
enum TypeEmbeddings {
    /// 11 种内容类型及其代表文本。
    /// 用于生成类型向量，实现零样本分类。
    static let typeDescriptions: [(ContentType, [String])] = [
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
            "TypeError: 'NoneType' object is not iterable",
            "Traceback (most recent call last): File 'app.py', line 42, in <module>",
            "RuntimeError: Failed to execute script 'main'",
            "Exception in thread main java.lang.NullPointerException"
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

    /// 基于嵌入服务预计算 11 种类型的向量缓存。
    /// - Parameter embed: 嵌入函数，返回文本的向量表示
    /// - Returns: ContentType 到向量数组的映射
    static func computeTypeVectors(using embed: (String) -> [Double]?) -> [ContentType: [Double]] {
        var cache: [ContentType: [Double]] = [:]
        for (type, texts) in typeDescriptions {
            let vectors = texts.compactMap { embed($0) }
            guard !vectors.isEmpty else { continue }
            cache[type] = averageVector(vectors)
        }
        return cache
    }

    /// 计算多个向量的平均向量。
    /// - Parameter vectors: 向量数组
    /// - Returns: 平均向量，若输入为空则返回空数组
    private static func averageVector(_ vectors: [[Double]]) -> [Double] {
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
}
