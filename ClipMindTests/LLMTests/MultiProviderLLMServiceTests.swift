@testable import ClipMind
import XCTest

/// MultiProviderLLMService 测试（T2.1）。
///
/// 验证：
/// - 4 个 provider 的请求 URL 正确
/// - 请求体格式（OpenAI 兼容 + DashScope）
/// - 响应解析正确
/// - extractTodos 解析 JSON 数组
/// - 错误处理（notConfigured/rateLimited/invalidAPIKey/serverError/timeout）
/// - AC-19: URLProtocol 拦截验证请求只发往已知 LLM endpoint
final class MultiProviderLLMServiceTests: XCTestCase {
    private var testSession: URLSession!

    override func setUp() {
        super.setUp()
        testSession = makeTestSession()
        InterceptingURLProtocol.capturedRequests.removeAll()
        InterceptingURLProtocol.capturedRequestBodies.removeAll()
        InterceptingURLProtocol.mockResponseData = nil
        InterceptingURLProtocol.mockStatusCode = nil
    }

    override func tearDown() {
        testSession = nil
        InterceptingURLProtocol.capturedRequests.removeAll()
        InterceptingURLProtocol.capturedRequestBodies.removeAll()
        InterceptingURLProtocol.mockResponseData = nil
        InterceptingURLProtocol.mockStatusCode = nil
        super.tearDown()
    }

    // MARK: - AC-19: 请求 URL 验证

    func testSummarizeSendsRequestToOpenAIEndpoint() async throws {
        InterceptingURLProtocol.mockResponseData = openAIResponse(content: "总结结果")
        InterceptingURLProtocol.mockStatusCode = 200

        let service = makeService()
        _ = try await service.summarize(text: "test")

        XCTAssertEqual(InterceptingURLProtocol.capturedRequests.count, 1)
        let url = InterceptingURLProtocol.capturedRequests[0].url?.absoluteString
        XCTAssertEqual(url, "https://api.openai.com/v1/chat/completions")
    }

    func testSummarizeSendsRequestToZhipuEndpoint() async throws {
        InterceptingURLProtocol.mockResponseData = openAIResponse(content: "总结结果")
        InterceptingURLProtocol.mockStatusCode = 200

        let service = makeService(provider: .zhipu)
        _ = try await service.summarize(text: "test")

        XCTAssertEqual(InterceptingURLProtocol.capturedRequests.count, 1)
        let url = InterceptingURLProtocol.capturedRequests[0].url?.absoluteString
        XCTAssertEqual(url, "https://open.bigmodel.cn/api/paas/v4/chat/completions")
    }

    func testSummarizeSendsRequestToDeepSeekEndpoint() async throws {
        InterceptingURLProtocol.mockResponseData = openAIResponse(content: "总结结果")
        InterceptingURLProtocol.mockStatusCode = 200

        let service = makeService(provider: .deepseek)
        _ = try await service.summarize(text: "test")

        XCTAssertEqual(InterceptingURLProtocol.capturedRequests.count, 1)
        let url = InterceptingURLProtocol.capturedRequests[0].url?.absoluteString
        XCTAssertEqual(url, "https://api.deepseek.com/v1/chat/completions")
    }

    func testSummarizeSendsRequestToQianwenEndpoint() async throws {
        InterceptingURLProtocol.mockResponseData = dashScopeResponse(content: "总结结果")
        InterceptingURLProtocol.mockStatusCode = 200

        let service = makeService(provider: .qianwen)
        _ = try await service.summarize(text: "test")

        XCTAssertEqual(InterceptingURLProtocol.capturedRequests.count, 1)
        let url = InterceptingURLProtocol.capturedRequests[0].url?.absoluteString
        XCTAssertEqual(url, "https://dashscope.aliyuncs.com/api/v1/services/aigc/text-generation/generation")
    }

    // MARK: - 请求体格式验证

    func testRequestBodyContainsSystemAndUserMessages() async throws {
        InterceptingURLProtocol.mockResponseData = openAIResponse(content: "result")
        InterceptingURLProtocol.mockStatusCode = 200

        let service = makeService()
        _ = try await service.summarize(text: "user input text")

        let bodyData = InterceptingURLProtocol.capturedRequestBodies[0]
        let body = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
        let messages = body?["messages"] as? [[String: String]]

        XCTAssertNotNil(messages)
        XCTAssertGreaterThanOrEqual(messages?.count ?? 0, 2)
        XCTAssertEqual(messages?[0]["role"], "system")
        XCTAssertFalse(messages?[0]["content"]?.isEmpty ?? true, "system prompt 不应为空")
        XCTAssertEqual(messages?[1]["role"], "user")
        XCTAssertTrue(messages?[1]["content"]?.contains("user input text") ?? false,
                      "user prompt 应包含输入文本")
    }

    func testRequestContainsAuthorizationHeader() async throws {
        InterceptingURLProtocol.mockResponseData = openAIResponse(content: "result")
        InterceptingURLProtocol.mockStatusCode = 200

        let service = makeService(apiKey: "my-secret-key")
        _ = try await service.summarize(text: "test")

        let request = InterceptingURLProtocol.capturedRequests[0]
        let auth = request.value(forHTTPHeaderField: "Authorization")
        XCTAssertEqual(auth, "Bearer my-secret-key")
    }

    // MARK: - 响应解析

    func testSummarizeParsesResponseContent() async throws {
        InterceptingURLProtocol.mockResponseData = openAIResponse(content: "这是总结的内容")
        InterceptingURLProtocol.mockStatusCode = 200

        let service = makeService(apiKey: "key")
        let result = try await service.summarize(text: "test")

        XCTAssertEqual(result, "这是总结的内容")
    }

    func testTranslateParsesResponseContent() async throws {
        InterceptingURLProtocol.mockResponseData = openAIResponse(content: "原文：Hi\n译文：你好")
        InterceptingURLProtocol.mockStatusCode = 200

        let service = makeService(apiKey: "key")
        let result = try await service.translate(text: "Hi", from: "en", to: "zh")

        XCTAssertEqual(result, "原文：Hi\n译文：你好")
    }

    func testRewriteParsesResponseContent() async throws {
        InterceptingURLProtocol.mockResponseData = openAIResponse(content: "改写后的文本")
        InterceptingURLProtocol.mockStatusCode = 200

        let service = makeService(apiKey: "key")
        let result = try await service.rewrite(text: "原文", mode: .condense)

        XCTAssertEqual(result, "改写后的文本")
    }

    // MARK: - extractTodos 解析

    func testExtractTodosParsesJsonArrayFromContent() async throws {
        let todoJson = "[{\"task\":\"完成任务\",\"assignee\":\"张三\",\"dueDate\":\"2025-01-15\"}]"
        InterceptingURLProtocol.mockResponseData = openAIResponse(content: todoJson)
        InterceptingURLProtocol.mockStatusCode = 200

        let service = makeService(apiKey: "key")
        let todos = try await service.extractTodos(text: "会议纪要")

        XCTAssertEqual(todos.count, 1)
        XCTAssertEqual(todos.first?.task, "完成任务")
        XCTAssertEqual(todos.first?.assignee, "张三")
        XCTAssertEqual(todos.first?.dueDate, "2025-01-15")
    }

    func testExtractTodosReturnsEmptyArrayWhenNoTodos() async throws {
        InterceptingURLProtocol.mockResponseData = openAIResponse(content: "[]")
        InterceptingURLProtocol.mockStatusCode = 200

        let service = makeService(apiKey: "key")
        let todos = try await service.extractTodos(text: "无任务的文本")

        XCTAssertTrue(todos.isEmpty)
    }

    func testExtractTodosThrowsParseErrorWhenContentNotJson() async throws {
        InterceptingURLProtocol.mockResponseData = openAIResponse(content: "这不是JSON")
        InterceptingURLProtocol.mockStatusCode = 200

        let service = makeService(apiKey: "key")

        do {
            _ = try await service.extractTodos(text: "test")
            XCTFail("应抛出 parseError")
        } catch let error as LLMError {
            if case .parseError = error {
                // 预期行为
            } else {
                XCTFail("应为 parseError")
            }
        } catch {
            XCTFail("应抛出 LLMError")
        }
    }

    // MARK: - DashScope（通义）响应解析

    func testQianwenParsesDashScopeResponse() async throws {
        InterceptingURLProtocol.mockResponseData = dashScopeResponse(content: "通义的结果")
        InterceptingURLProtocol.mockStatusCode = 200

        let service = MultiProviderLLMService(provider: .qianwen, apiKey: "key", urlSession: testSession)
        let result = try await service.summarize(text: "test")

        XCTAssertEqual(result, "通义的结果")
    }

    // MARK: - 错误处理

    func testThrowsNotConfiguredWhenApiKeyIsEmpty() async {
        let service = makeService(apiKey: "")

        do {
            _ = try await service.summarize(text: "test")
            XCTFail("应抛出 notConfigured")
        } catch let error as LLMError {
            XCTAssertEqual(error, .notConfigured)
        } catch {
            XCTFail("应抛出 LLMError")
        }
    }

    func testThrowsInvalidAPIKeyOn401() async {
        InterceptingURLProtocol.mockResponseData = Data("{\"error\":{\"message\":\"Invalid API key\"}}".utf8)
        InterceptingURLProtocol.mockStatusCode = 401

        let service = makeService(apiKey: "bad-key")

        do {
            _ = try await service.summarize(text: "test")
            XCTFail("应抛出 invalidAPIKey")
        } catch let error as LLMError {
            XCTAssertEqual(error, .invalidAPIKey)
        } catch {
            XCTFail("应抛出 LLMError")
        }
    }

    func testThrowsRateLimitedOn429() async {
        InterceptingURLProtocol.mockResponseData = Data("{\"error\":{\"message\":\"Rate limited\"}}".utf8)
        InterceptingURLProtocol.mockStatusCode = 429

        let service = makeService(apiKey: "key")

        do {
            _ = try await service.summarize(text: "test")
            XCTFail("应抛出 rateLimited")
        } catch let error as LLMError {
            XCTAssertEqual(error, .rateLimited)
        } catch {
            XCTFail("应抛出 LLMError")
        }
    }

    func testThrowsServerErrorOn500() async {
        InterceptingURLProtocol.mockResponseData = Data("{\"error\":{\"message\":\"Server error\"}}".utf8)
        InterceptingURLProtocol.mockStatusCode = 500

        let service = makeService(apiKey: "key")

        do {
            _ = try await service.summarize(text: "test")
            XCTFail("应抛出 serverError")
        } catch let error as LLMError {
            if case .serverError(let code) = error {
                XCTAssertEqual(code, 500)
            } else {
                XCTFail("应为 serverError")
            }
        } catch {
            XCTFail("应抛出 LLMError")
        }
    }

    // MARK: - 辅助方法

    private func makeService(provider: APIProvider = .openai, apiKey: String = "test-key") -> MultiProviderLLMService {
        let service = MultiProviderLLMService(provider: provider, apiKey: apiKey, urlSession: testSession)
        service.retryDelay = 0.01
        return service
    }

    private func makeTestSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [InterceptingURLProtocol.self]
        config.timeoutIntervalForRequest = 5
        return URLSession(configuration: config)
    }

    private func openAIResponse(content: String) -> Data {
        let response: [String: Any] = [
            "choices": [["message": ["role": "assistant", "content": content]]]
        ]
        return (try? JSONSerialization.data(withJSONObject: response)) ?? Data()
    }

    private func dashScopeResponse(content: String) -> Data {
        let response: [String: Any] = [
            "output": ["choices": [["message": ["content": content]]]]
        ]
        return (try? JSONSerialization.data(withJSONObject: response)) ?? Data()
    }
}
