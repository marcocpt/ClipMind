@testable import ClipMind
import XCTest

/// LLMService 协议基础测试（T2.1）。
///
/// 验证：
/// - LLMService 协议的 4 个方法契约
/// - MockLLMService 的 mock 行为（配置响应、记录调用、抛出错误）
/// - LLMError 各 case 的错误描述
/// - InterceptingURLProtocol 测试基础设施可用
final class LLMServiceTests: XCTestCase {
    private var mock: MockLLMService!

    override func setUp() {
        super.setUp()
        mock = MockLLMService()
    }

    override func tearDown() {
        mock = nil
        super.tearDown()
    }

    // MARK: - summarize

    func testSummarizeReturnsConfiguredResponse() async throws {
        mock.summarizeResult = "核心要点1。核心要点2。"
        let result = try await mock.summarize(text: "一段长文本")
        XCTAssertEqual(result, "核心要点1。核心要点2。")
    }

    func testSummarizeRecordsCallArgument() async throws {
        _ = try? await mock.summarize(text: "被总结的文本")
        XCTAssertEqual(mock.summarizeCalls, ["被总结的文本"])
    }

    func testSummarizeThrowsConfiguredError() async {
        mock.summarizeError = LLMError.notConfigured
        do {
            _ = try await mock.summarize(text: "any")
            XCTFail("应抛出 notConfigured 错误")
        } catch let error as LLMError {
            XCTAssertEqual(error, .notConfigured)
        } catch {
            XCTFail("应抛出 LLMError，实际：\(error)")
        }
    }

    // MARK: - translate

    func testTranslateReturnsConfiguredResponse() async throws {
        mock.translateResult = "Hello / 你好"
        let result = try await mock.translate(text: "Hello", from: "en", to: "zh")
        XCTAssertEqual(result, "Hello / 你好")
    }

    func testTranslateRecordsCallArguments() async throws {
        _ = try? await mock.translate(text: "Hello", from: "en", to: "zh")
        XCTAssertEqual(mock.translateCalls.count, 1)
        let call = mock.translateCalls[0]
        XCTAssertEqual(call.text, "Hello")
        XCTAssertEqual(call.from, "en")
        XCTAssertEqual(call.to, "zh")
    }

    func testTranslateThrowsConfiguredError() async {
        mock.translateError = LLMError.timeout
        do {
            _ = try await mock.translate(text: "x", from: "en", to: "zh")
            XCTFail("应抛出 timeout 错误")
        } catch let error as LLMError {
            XCTAssertEqual(error, .timeout)
        } catch {
            XCTFail("应抛出 LLMError")
        }
    }

    // MARK: - rewrite

    func testRewriteReturnsConfiguredResponse() async throws {
        mock.rewriteResult = "改写后的文本"
        let result = try await mock.rewrite(text: "原文", mode: .condense)
        XCTAssertEqual(result, "改写后的文本")
    }

    func testRewriteRecordsCallArguments() async throws {
        _ = try? await mock.rewrite(text: "原文", mode: .expand)
        XCTAssertEqual(mock.rewriteCalls.count, 1)
        let call = mock.rewriteCalls[0]
        XCTAssertEqual(call.text, "原文")
        XCTAssertEqual(call.mode, .expand)
    }

    func testRewriteThrowsConfiguredError() async {
        mock.rewriteError = LLMError.rateLimited
        do {
            _ = try await mock.rewrite(text: "x", mode: .adjustTone)
            XCTFail("应抛出 rateLimited 错误")
        } catch let error as LLMError {
            XCTAssertEqual(error, .rateLimited)
        } catch {
            XCTFail("应抛出 LLMError")
        }
    }

    // MARK: - extractTodos

    func testExtractTodosReturnsConfiguredResponse() async throws {
        let todos = [TodoItem(id: UUID(), task: "完成任务", assignee: "张三", dueDate: "2025-01-15")]
        mock.extractTodosResult = todos
        let result = try await mock.extractTodos(text: "明天张三完成任务")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.task, "完成任务")
    }

    func testExtractTodosRecordsCallArgument() async throws {
        _ = try? await mock.extractTodos(text: "提取待办的文本")
        XCTAssertEqual(mock.extractTodosCalls, ["提取待办的文本"])
    }

    func testExtractTodosThrowsConfiguredError() async {
        mock.extractTodosError = LLMError.parseError("无效 JSON")
        do {
            _ = try await mock.extractTodos(text: "x")
            XCTFail("应抛出 parseError 错误")
        } catch let error as LLMError {
            if case .parseError(let message) = error {
                XCTAssertEqual(message, "无效 JSON")
            } else {
                XCTFail("应为 parseError")
            }
        } catch {
            XCTFail("应抛出 LLMError")
        }
    }

    // MARK: - LLMError 错误描述

    func testNotConfiguredErrorDescription() {
        XCTAssertFalse(LLMError.notConfigured.errorDescription?.isEmpty ?? true)
    }

    func testInvalidAPIKeyErrorDescription() {
        XCTAssertFalse(LLMError.invalidAPIKey.errorDescription?.isEmpty ?? true)
    }

    func testRateLimitedErrorDescription() {
        XCTAssertFalse(LLMError.rateLimited.errorDescription?.isEmpty ?? true)
    }

    func testTimeoutErrorDescription() {
        XCTAssertFalse(LLMError.timeout.errorDescription?.isEmpty ?? true)
    }

    func testServerErrorErrorDescription() {
        let error = LLMError.serverError(500)
        XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
        XCTAssertTrue(error.errorDescription?.contains("500") ?? false, "serverError 描述应包含状态码")
    }

    func testParseErrorErrorDescription() {
        let error = LLMError.parseError("解析失败原因")
        XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
    }

    func testNetworkErrorDescription() {
        let nsError = NSError(domain: "test", code: 42)
        let error = LLMError.networkError(nsError)
        XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
    }

    // MARK: - LLMError Equatable

    func testLLMErrorEquality() {
        XCTAssertEqual(LLMError.notConfigured, .notConfigured)
        XCTAssertEqual(LLMError.invalidAPIKey, .invalidAPIKey)
        XCTAssertEqual(LLMError.rateLimited, .rateLimited)
        XCTAssertEqual(LLMError.timeout, .timeout)
        XCTAssertEqual(LLMError.serverError(500), .serverError(500))
        XCTAssertNotEqual(LLMError.serverError(500), .serverError(503))
        XCTAssertEqual(LLMError.parseError("a"), .parseError("a"))
        XCTAssertNotEqual(LLMError.parseError("a"), .parseError("b"))
    }

    // MARK: - InterceptingURLProtocol 基础设施（AC-19 数据不出本机）

    func testInterceptingURLProtocolCapturesRequestURL() {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [InterceptingURLProtocol.self]
        let session = URLSession(configuration: config)

        let expectation = expectation(description: "请求完成")
        InterceptingURLProtocol.capturedRequests.removeAll()
        InterceptingURLProtocol.capturedRequestBodies.removeAll()

        let url = URL(string: "https://api.example.com/test")!
        let task = session.dataTask(with: url) { _, _, _ in
            expectation.fulfill()
        }
        task.resume()
        wait(for: [expectation], timeout: 2.0)

        XCTAssertEqual(InterceptingURLProtocol.capturedRequests.count, 1)
        XCTAssertEqual(InterceptingURLProtocol.capturedRequests.first?.url?.absoluteString,
                       "https://api.example.com/test")
    }

    func testInterceptingURLProtocolCanReturnMockResponse() {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [InterceptingURLProtocol.self]
        let session = URLSession(configuration: config)

        InterceptingURLProtocol.capturedRequests.removeAll()
        InterceptingURLProtocol.capturedRequestBodies.removeAll()
        InterceptingURLProtocol.mockResponseData = Data("{\"ok\":true}".utf8)
        InterceptingURLProtocol.mockStatusCode = 200

        let expectation = expectation(description: "请求完成")
        let url = URL(string: "https://api.example.com/mock")!
        var receivedData: Data?
        var receivedStatus: Int?

        let task = session.dataTask(with: url) { data, response, _ in
            receivedData = data
            if let http = response as? HTTPURLResponse {
                receivedStatus = http.statusCode
            }
            expectation.fulfill()
        }
        task.resume()
        wait(for: [expectation], timeout: 2.0)

        XCTAssertEqual(receivedData, Data("{\"ok\":true}".utf8))
        XCTAssertEqual(receivedStatus, 200)

        // 清理 mock 状态
        InterceptingURLProtocol.mockResponseData = nil
        InterceptingURLProtocol.mockStatusCode = nil
    }
}
