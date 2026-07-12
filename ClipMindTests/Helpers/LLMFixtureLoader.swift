@testable import ClipMind
import Foundation

/// LLM mock 响应 fixture 加载器（T2.3）。
///
/// 从 `llm_mock_responses.json` 加载预定义的 mock 响应和错误场景，
/// 供 AC-13~16 验收测试使用。
enum LLMFixtureLoader {
    /// fixture 文件名（位于测试 bundle 中）
    static let fileName = "llm_mock_responses"

    /// 加载并解析 fixture 文件。
    /// - Returns: 解析后的 `LLMFixture` 结构
    /// - Throws: 文件不存在或 JSON 解析失败时抛错
    static func load() throws -> LLMFixture {
        let bundle = Bundle(for: MockLLMService.self)
        guard let url = bundle.url(forResource: fileName, withExtension: "json") else {
            throw FixtureError.fileNotFound(fileName)
        }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        return try decoder.decode(LLMFixture.self, from: data)
    }

    /// fixture 加载错误
    enum FixtureError: Error {
        case fileNotFound(String)
    }
}

/// fixture 文件的 Codable 结构。
struct LLMFixture: Codable {
    let responses: Responses
    let errors: Errors
}

extension LLMFixture {
    struct Responses: Codable {
        let summarize: [String]
        let translate: [String]
        let rewrite: RewriteResponses
        let extractTodo: [ExtractTodoResponse]

        // swiftlint:disable:next nesting
        enum CodingKeys: String, CodingKey {
            case summarize
            case translate
            case rewrite
            case extractTodo = "extract_todo"
        }
    }

    struct RewriteResponses: Codable {
        let adjustTone: String
        let condense: String
        let expand: String

        // swiftlint:disable:next nesting
        enum CodingKeys: String, CodingKey {
            case adjustTone = "adjust_tone"
            case condense
            case expand
        }
    }

    struct ExtractTodoResponse: Codable {
        let todos: [FixtureTodoItem]
    }

    struct FixtureTodoItem: Codable {
        let task: String
        let assignee: String?
        let dueDate: String?
    }
}

extension LLMFixture {
    struct Errors: Codable {
        let rateLimited: ErrorEntry
        let invalidKey: ErrorEntry
        let timeout: TimeoutError
        let serverError: ErrorEntry

        // swiftlint:disable:next nesting
        enum CodingKeys: String, CodingKey {
            case rateLimited = "rate_limited"
            case invalidKey = "invalid_key"
            case timeout
            case serverError = "server_error"
        }
    }

    struct ErrorEntry: Codable {
        let status: Int
        let body: String
    }

    struct TimeoutError: Codable {
        let error: String
        let message: String
    }
}
