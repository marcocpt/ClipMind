import Foundation

/// LLM API 请求/响应的 Codable 结构。

/// 聊天消息（system/user/assistant 角色 + 内容）
struct ChatMessage: Codable {
    let role: String
    let content: String
}

/// OpenAI 兼容请求体（openai/zhipu/deepseek 使用）
struct ChatRequestBody: Codable {
    let model: String
    let messages: [ChatMessage]
}

/// DashScope 请求体（通义 qianwen 使用）
struct DashScopeRequestBody: Codable {
    let model: String
    let input: DashScopeInput
}

/// DashScope 请求的 input 字段
struct DashScopeInput: Codable {
    let messages: [ChatMessage]
}

/// OpenAI 兼容响应体
struct ChatResponse: Codable {
    let choices: [ChatChoice]
}

/// 响应中的 choice 项
struct ChatChoice: Codable {
    let message: ChatResponseMessage
}

/// 响应中的消息
struct ChatResponseMessage: Codable {
    let content: String
}

/// DashScope 响应体
struct DashScopeResponse: Codable {
    let output: DashScopeOutput
}

/// DashScope 响应的 output 字段
struct DashScopeOutput: Codable {
    let choices: [ChatChoice]
}

/// LLM 返回的待办项（无 id，转换时生成）
struct LLMTodoItem: Codable {
    let task: String
    let assignee: String?
    let dueDate: String?
}

/// 多提供商 LLM 服务实现（T2.1）。
///
/// 根据 `APIProvider` 路由到对应的 API endpoint：
/// - OpenAI: https://api.openai.com/v1/chat/completions
/// - 智谱: https://open.bigmodel.cn/api/paas/v4/chat/completions
/// - 通义: https://dashscope.aliyuncs.com/api/v1/services/aigc/text-generation/generation
/// - DeepSeek: https://api.deepseek.com/v1/chat/completions
///
/// 特性：
/// - 30s 请求超时
/// - 最多 2 次重试（指数退避）
/// - OpenAI 兼容格式 + DashScope 格式
/// - 使用 PromptTemplates 构建 system prompt
final class MultiProviderLLMService: LLMService {
    private let provider: APIProvider
    private let apiKey: String
    private let urlSession: URLSession
    private let maxRetries = 2
    private let requestTimeout: TimeInterval = 30

    /// 重试延迟基数（秒），实际延迟为 retryDelay * 2^attempt
    var retryDelay: TimeInterval = 1.0

    /// 初始化。
    /// - Parameters:
    ///   - provider: API 提供商
    ///   - apiKey: API Key
    ///   - urlSession: URLSession 实例（默认 .shared，测试可注入）
    init(provider: APIProvider, apiKey: String, urlSession: URLSession = .shared) {
        self.provider = provider
        self.apiKey = apiKey
        self.urlSession = urlSession
    }

    // MARK: - LLMService 实现

    func summarize(text: String) async throws -> String {
        try await sendRequest(
            systemPrompt: PromptTemplates.summarizeSystemPrompt,
            userPrompt: PromptTemplates.buildSummarizeUserPrompt(text: text)
        )
    }

    // swiftlint:disable:next identifier_name
    func translate(text: String, from: String, to: String) async throws -> String {
        try await sendRequest(
            systemPrompt: PromptTemplates.translateSystemPrompt,
            userPrompt: PromptTemplates.buildTranslateUserPrompt(text: text, from: from, to: to)
        )
    }

    func rewrite(text: String, mode: RewriteMode) async throws -> String {
        try await sendRequest(
            systemPrompt: PromptTemplates.rewriteSystemPrompt,
            userPrompt: PromptTemplates.buildRewriteUserPrompt(text: text, mode: mode)
        )
    }

    func extractTodos(text: String) async throws -> [TodoItem] {
        let content = try await sendRequest(
            systemPrompt: PromptTemplates.extractTodoSystemPrompt,
            userPrompt: PromptTemplates.buildExtractTodoUserPrompt(text: text)
        )
        return try parseTodosContent(content)
    }

    // MARK: - 请求构建

    /// 根据 provider 返回对应的 API endpoint URL
    private var endpointURL: URL {
        switch provider {
        case .openai:
            return URL(string: "https://api.openai.com/v1/chat/completions")!
        case .zhipu:
            return URL(string: "https://open.bigmodel.cn/api/paas/v4/chat/completions")!
        case .qianwen:
            return URL(string: "https://dashscope.aliyuncs.com/api/v1/services/aigc/text-generation/generation")!
        case .deepseek:
            return URL(string: "https://api.deepseek.com/v1/chat/completions")!
        }
    }

    /// 根据 provider 返回模型名
    private var modelName: String {
        switch provider {
        case .openai:
            return "gpt-4o-mini"
        case .zhipu:
            return "glm-4-flash"
        case .qianwen:
            return "qwen-turbo"
        case .deepseek:
            return "deepseek-chat"
        }
    }

    /// 构建 URLRequest
    private func buildRequest(systemPrompt: String, userPrompt: String) throws -> URLRequest {
        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.timeoutInterval = requestTimeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let messages = [
            ChatMessage(role: "system", content: systemPrompt),
            ChatMessage(role: "user", content: userPrompt)
        ]

        let bodyData: Data
        if provider == .qianwen {
            let body = DashScopeRequestBody(model: modelName, input: DashScopeInput(messages: messages))
            bodyData = try JSONEncoder().encode(body)
        } else {
            let body = ChatRequestBody(model: modelName, messages: messages)
            bodyData = try JSONEncoder().encode(body)
        }
        request.httpBody = bodyData
        return request
    }

    // MARK: - 请求发送与重试

    /// 发送请求并返回解析后的内容
    private func sendRequest(systemPrompt: String, userPrompt: String) async throws -> String {
        guard !apiKey.isEmpty else {
            LogCategory.llm.warning("API Key 为空，拒绝请求")
            throw LLMError.notConfigured
        }

        let request = try buildRequest(systemPrompt: systemPrompt, userPrompt: userPrompt)
        let data = try await sendWithRetry(request)
        return try parseResponse(data)
    }

    /// 带重试的请求发送
    private func sendWithRetry(_ request: URLRequest) async throws -> Data {
        for attempt in 0...maxRetries {
            do {
                return try await executeRequest(request)
            } catch let error as LLMError where shouldRetry(error) && attempt < maxRetries {
                LogCategory.llm.warning("请求失败（第 \(attempt) 次），将重试: \(error.localizedDescription)")
                await sleepForRetry(attempt: attempt)
                continue
            } catch let error as LLMError {
                throw error
            } catch {
                if attempt < maxRetries {
                    await sleepForRetry(attempt: attempt)
                    continue
                }
                throw LLMError.networkError(error)
            }
        }
        throw LLMError.networkError(NSError(domain: "LLMService", code: -1))
    }

    /// 执行单次请求
    private func executeRequest(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await urlSession.data(for: request)
        try validateResponse(response)
        return data
    }

    /// 判断错误是否应重试
    private func shouldRetry(_ error: LLMError) -> Bool {
        switch error {
        case .serverError, .rateLimited, .networkError, .timeout:
            return true
        default:
            return false
        }
    }

    /// 指数退避等待
    private func sleepForRetry(attempt: Int) async {
        let delay = retryDelay * pow(2.0, Double(attempt))
        let nanos = UInt64(delay * 1_000_000_000)
        try? await Task.sleep(nanoseconds: nanos)
    }

    /// 校验 HTTP 响应状态码
    private func validateResponse(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw LLMError.networkError(NSError(domain: "LLMService", code: -1))
        }
        switch http.statusCode {
        case 200...299:
            return
        case 401:
            LogCategory.llm.error("API Key 无效 (401)")
            throw LLMError.invalidAPIKey
        case 429:
            LogCategory.llm.warning("请求被限流 (429)")
            throw LLMError.rateLimited
        case 500...599:
            LogCategory.llm.error("服务器错误 (\(http.statusCode))")
            throw LLMError.serverError(http.statusCode)
        default:
            LogCategory.llm.error("未知错误 (\(http.statusCode))")
            throw LLMError.serverError(http.statusCode)
        }
    }

    // MARK: - 响应解析

    /// 解析响应，提取生成内容
    private func parseResponse(_ data: Data) throws -> String {
        let decoder = JSONDecoder()
        if provider == .qianwen {
            let response = try decoder.decode(DashScopeResponse.self, from: data)
            guard let content = response.output.choices.first?.message.content else {
                throw LLMError.parseError("DashScope 响应缺少 content 字段")
            }
            return content
        }

        let response = try decoder.decode(ChatResponse.self, from: data)
        guard let content = response.choices.first?.message.content else {
            throw LLMError.parseError("响应缺少 content 字段")
        }
        return content
    }

    /// 解析 extractTodos 返回的 JSON 数组内容
    private func parseTodosContent(_ content: String) throws -> [TodoItem] {
        let data = Data(content.utf8)
        do {
            let llmTodos = try JSONDecoder().decode([LLMTodoItem].self, from: data)
            return llmTodos.map {
                TodoItem(id: UUID(), task: $0.task, assignee: $0.assignee, dueDate: $0.dueDate)
            }
        } catch {
            throw LLMError.parseError("无法解析为待办 JSON 数组: \(error.localizedDescription)")
        }
    }
}
