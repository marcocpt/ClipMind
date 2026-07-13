import Foundation

/// LLM 服务协议（T2.1）。
///
/// 定义 4 种一键 AI 处理能力的契约：
/// - 智能总结：长文本 → 3-5 句核心要点
/// - 即时翻译：中英对照 + 保留技术术语
/// - 智能改写：3 种模式（调整语气/精简/扩写）
/// - 提取待办：结构化任务列表（task + assignee + dueDate）
///
/// 所有方法均为 async throws，错误以 `LLMError` 抛出。
/// 实现类（如 `MultiProviderLLMService`）负责具体的 API 调用、重试和解析。
protocol LLMService {
    /// 智能总结。
    ///
    /// - Parameter text: 待总结的文本（建议 >200 字）
    /// - Returns: 3-5 句核心要点
    /// - Throws: `LLMError`
    func summarize(text: String) async throws -> String

    // swiftlint:disable identifier_name
    /// 即时翻译。
    ///
    /// - Parameters:
    ///   - text: 待翻译的文本
    ///   - from: 源语言代码（如 "zh"、"en"）
    ///   - to: 目标语言代码
    /// - Returns: 中英对照 + 保留技术术语原文
    /// - Throws: `LLMError`
    func translate(text: String, from: String, to: String) async throws -> String
    // swiftlint:enable identifier_name

    /// 智能改写。
    ///
    /// - Parameters:
    ///   - text: 待改写的文本
    ///   - mode: 改写模式（adjustTone/condense/expand）
    /// - Returns: 改写后的文本
    /// - Throws: `LLMError`
    func rewrite(text: String, mode: RewriteMode) async throws -> String

    /// 提取待办事项。
    ///
    /// - Parameter text: 待提取的文本（会议纪要、聊天、需求等）
    /// - Returns: 结构化任务列表（task + assignee + dueDate）
    /// - Throws: `LLMError`
    func extractTodos(text: String) async throws -> [TodoItem]
}
