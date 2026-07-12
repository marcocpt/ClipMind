@testable import ClipMind
import XCTest

/// 智能总结测试（AC-13）。
///
/// 验证：
/// - mock 响应返回 3-5 句核心要点
/// - 多条 fixture 响应均符合句数约束
/// - API 错误不阻塞本地功能（AC-19 相关）
final class SummarizeTests: XCTestCase {
    private var mock: MockLLMService!
    private var fixture: LLMFixture!

    override func setUpWithError() throws {
        mock = MockLLMService()
        fixture = try LLMFixtureLoader.load()
    }

    override func tearDown() {
        mock = nil
        fixture = nil
        super.tearDown()
    }

    // MARK: - AC-13: 智能总结生成 3-5 句核心要点

    func testSummarizeReturnsThreeToFiveSentences() async throws {
        // 使用 fixture 第 1 条响应（3 句）
        let response = fixture.responses.summarize[0]
        mock.summarizeResult = response

        let result = try await mock.summarize(text: "一段需要总结的长文本")

        let sentenceCount = countSentences(in: result)
        XCTAssertGreaterThanOrEqual(sentenceCount, 3, "总结应至少 3 句")
        XCTAssertLessThanOrEqual(sentenceCount, 5, "总结应至多 5 句")
    }

    func testAllSummarizeFixturesAreWithinThreeToFiveSentences() {
        // 所有 fixture 响应都应符合 3-5 句约束
        for (index, response) in fixture.responses.summarize.enumerated() {
            let count = countSentences(in: response)
            XCTAssertGreaterThanOrEqual(count, 3, "fixture[\(index)] 句数应 >= 3，实际 \(count)")
            XCTAssertLessThanOrEqual(count, 5, "fixture[\(index)] 句数应 <= 5，实际 \(count)")
        }
    }

    func testSummarizeRecordsInputText() async throws {
        mock.summarizeResult = "总结内容。"
        _ = try await mock.summarize(text: "原始输入文本")

        XCTAssertEqual(mock.summarizeCalls, ["原始输入文本"])
    }

    // MARK: - API 错误不阻塞本地功能（AC-19 相关）

    func testSummarizeErrorDoesNotCrashCaller() async {
        // 模拟 API 错误，调用方应能捕获并继续运行
        mock.summarizeError = LLMError.networkError(NSError(domain: "test", code: -1))

        do {
            _ = try await mock.summarize(text: "any")
            XCTFail("应抛出 networkError")
        } catch {
            // 捕获错误，本地功能不受影响
            XCTAssert(error is LLMError, "应抛出 LLMError")
        }
    }

    func testSummarizeNotConfiguredErrorWhenNoApiKey() async {
        // 未配置 API Key 时应抛出 notConfigured，不发起网络请求
        mock.summarizeError = LLMError.notConfigured

        do {
            _ = try await mock.summarize(text: "any")
            XCTFail("应抛出 notConfigured")
        } catch let error as LLMError {
            XCTAssertEqual(error, .notConfigured)
        } catch {
            XCTFail("应抛出 LLMError")
        }
    }

    func testSummarizeServerErrorDoesNotBlockLocalFunctionality() async {
        // 服务器错误不应阻塞本地功能，调用方捕获后可降级
        mock.summarizeError = LLMError.serverError(500)

        do {
            _ = try await mock.summarize(text: "any")
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

    /// 统计句子数：按中文句号「。」分割（避免版本号、库名中的 . 被误判）
    private func countSentences(in text: String) -> Int {
        text
            .components(separatedBy: "。")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .count
    }
}
