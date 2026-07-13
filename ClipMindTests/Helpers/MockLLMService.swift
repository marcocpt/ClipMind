@testable import ClipMind
import Foundation

/// 翻译调用的参数记录
struct TranslateCall: Equatable {
    let text: String
    let from: String
    // swiftlint:disable:next identifier_name
    let to: String
}

/// 改写调用的参数记录
struct RewriteCall: Equatable {
    let text: String
    let mode: RewriteMode
}

/// 测试用 LLMService mock 实现（T2.1）。
///
/// 特性：
/// - 可配置每个方法的返回值（`summarizeResult` 等）
/// - 可配置每个方法抛出的错误（`summarizeError` 等）
/// - 记录每个方法的调用参数（`summarizeCalls` 等）
///
/// 用法：
/// ```swift
/// let mock = MockLLMService()
/// mock.summarizeResult = "总结内容"
/// mock.summarizeError = LLMError.notConfigured
/// ```
final class MockLLMService: LLMService {
    // MARK: - 配置的返回值

    var summarizeResult: String?
    var translateResult: String?
    var rewriteResult: String?
    var extractTodosResult: [TodoItem]?

    // MARK: - 配置的错误

    var summarizeError: LLMError?
    var translateError: LLMError?
    var rewriteError: LLMError?
    var extractTodosError: LLMError?

    // MARK: - 调用记录

    private(set) var summarizeCalls: [String] = []
    private(set) var translateCalls: [TranslateCall] = []
    private(set) var rewriteCalls: [RewriteCall] = []
    private(set) var extractTodosCalls: [String] = []

    // MARK: - LLMService 实现

    func summarize(text: String) async throws -> String {
        summarizeCalls.append(text)
        if let summarizeError {
            throw summarizeError
        }
        return summarizeResult ?? ""
    }

    // swiftlint:disable:next identifier_name
    func translate(text: String, from: String, to: String) async throws -> String {
        translateCalls.append(TranslateCall(text: text, from: from, to: to))
        if let translateError {
            throw translateError
        }
        return translateResult ?? ""
    }

    func rewrite(text: String, mode: RewriteMode) async throws -> String {
        rewriteCalls.append(RewriteCall(text: text, mode: mode))
        if let rewriteError {
            throw rewriteError
        }
        return rewriteResult ?? ""
    }

    func extractTodos(text: String) async throws -> [TodoItem] {
        extractTodosCalls.append(text)
        if let extractTodosError {
            throw extractTodosError
        }
        return extractTodosResult ?? []
    }
}
