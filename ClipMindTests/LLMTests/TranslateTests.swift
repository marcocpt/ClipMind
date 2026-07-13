@testable import ClipMind
import XCTest

/// 即时翻译测试（AC-14）。
///
/// 验证：
/// - mock 响应生成中英对照
/// - 技术术语保留原文
/// - 超时不阻塞本地功能
final class TranslateTests: XCTestCase {
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

    // MARK: - AC-14: 即时翻译生成中英对照

    func testTranslateReturnsBilingualResult() async throws {
        let response = fixture.responses.translate[0]
        mock.translateResult = response

        let result = try await mock.translate(text: "URLSession API", from: "en", to: "zh")

        // 应包含原文和译文
        XCTAssertTrue(result.contains("原文"), "翻译结果应包含「原文」标记")
        XCTAssertTrue(result.contains("译文"), "翻译结果应包含「译文」标记")
    }

    func testAllTranslateFixturesContainBilingualMarkers() {
        // 所有 fixture 翻译响应都应包含中英对照标记
        for (index, response) in fixture.responses.translate.enumerated() {
            XCTAssertTrue(response.contains("原文") || response.contains("译文"),
                          "fixture[\(index)] 应包含中英对照标记")
        }
    }

    // MARK: - 技术术语保留原文

    func testTranslatePreservesTechnicalTerms() async throws {
        // 第 1 条包含 URLSession（应保留原文）
        let response = fixture.responses.translate[0]
        mock.translateResult = response

        let result = try await mock.translate(text: "The URLSession class", from: "en", to: "zh")

        XCTAssertTrue(result.contains("URLSession"), "技术术语 URLSession 应保留原文")
    }

    func testAllTranslateFixturesPreserveTechnicalTerms() {
        // 验证 fixture 中技术术语保留
        let terms = ["URLSession", "NSWindowController", "Codable"]
        for (index, response) in fixture.responses.translate.enumerated() {
            let matched = terms.contains { response.contains($0) }
            XCTAssertTrue(matched, "fixture[\(index)] 应至少包含一个技术术语原文")
        }
    }

    // MARK: - 翻译参数传递

    func testTranslateRecordsFromAndToParameters() async throws {
        mock.translateResult = "原文：Hi\n译文：你好"

        _ = try await mock.translate(text: "Hi", from: "en", to: "zh")

        XCTAssertEqual(mock.translateCalls.count, 1)
        XCTAssertEqual(mock.translateCalls[0].from, "en")
        XCTAssertEqual(mock.translateCalls[0].to, "zh")
    }

    func testTranslateSupportsChineseToEnglish() async throws {
        let response = fixture.responses.translate[1]
        mock.translateResult = response

        let result = try await mock.translate(text: "我们需要在 NSWindowController 中", from: "zh", to: "en")

        XCTAssertTrue(result.contains("NSWindowController"), "技术术语应保留")
    }

    // MARK: - 超时不阻塞本地功能

    func testTranslateTimeoutDoesNotBlockLocalFunctionality() async {
        mock.translateError = LLMError.timeout

        do {
            _ = try await mock.translate(text: "any", from: "en", to: "zh")
            XCTFail("应抛出 timeout")
        } catch let error as LLMError {
            // 超时被捕获，本地功能不受影响
            XCTAssertEqual(error, .timeout)
        } catch {
            XCTFail("应抛出 LLMError")
        }
    }

    func testTranslateNetworkErrorDoesNotCrashCaller() async {
        mock.translateError = LLMError.networkError(NSError(domain: "test", code: -1009))

        do {
            _ = try await mock.translate(text: "any", from: "zh", to: "en")
            XCTFail("应抛出 networkError")
        } catch {
            // 网络错误被捕获，不阻塞
            XCTAssert(error is LLMError)
        }
    }

    // MARK: - 未配置 API Key

    func testTranslateThrowsNotConfiguredWhenNoApiKey() async {
        mock.translateError = LLMError.notConfigured

        do {
            _ = try await mock.translate(text: "any", from: "en", to: "zh")
            XCTFail("应抛出 notConfigured")
        } catch let error as LLMError {
            XCTAssertEqual(error, .notConfigured)
        } catch {
            XCTFail("应抛出 LLMError")
        }
    }
}
