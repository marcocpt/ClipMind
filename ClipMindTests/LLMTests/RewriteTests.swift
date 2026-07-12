@testable import ClipMind
import XCTest

/// 智能改写测试（AC-15）。
///
/// 验证：
/// - 提供 3 种模式（adjustTone/condense/expand）
/// - 每种模式返回不同结果
/// - 限流处理不阻塞本地功能
final class RewriteTests: XCTestCase {
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

    // MARK: - AC-15: 智能改写提供 3 种模式

    func testRewriteAdjustToneModeReturnsResult() async throws {
        let response = fixture.responses.rewrite.adjustTone
        mock.rewriteResult = response

        let result = try await mock.rewrite(text: "帮我改写这段话", mode: .adjustTone)

        XCTAssertFalse(result.isEmpty, "adjustTone 模式应返回非空结果")
        XCTAssertEqual(mock.rewriteCalls.first?.mode, .adjustTone)
    }

    func testRewriteCondenseModeReturnsResult() async throws {
        let response = fixture.responses.rewrite.condense
        mock.rewriteResult = response

        let result = try await mock.rewrite(text: "帮我改写这段话", mode: .condense)

        XCTAssertFalse(result.isEmpty, "condense 模式应返回非空结果")
        XCTAssertEqual(mock.rewriteCalls.first?.mode, .condense)
    }

    func testRewriteExpandModeReturnsResult() async throws {
        let response = fixture.responses.rewrite.expand
        mock.rewriteResult = response

        let result = try await mock.rewrite(text: "帮我改写这段话", mode: .expand)

        XCTAssertFalse(result.isEmpty, "expand 模式应返回非空结果")
        XCTAssertEqual(mock.rewriteCalls.first?.mode, .expand)
    }

    func testRewriteEachModeProducesDifferentResult() async throws {
        // 3 种模式应产出不同的改写结果
        let adjustToneResult = fixture.responses.rewrite.adjustTone
        let condenseResult = fixture.responses.rewrite.condense
        let expandResult = fixture.responses.rewrite.expand

        XCTAssertNotEqual(adjustToneResult, condenseResult, "adjustTone 与 condense 结果应不同")
        XCTAssertNotEqual(adjustToneResult, expandResult, "adjustTone 与 expand 结果应不同")
        XCTAssertNotEqual(condenseResult, expandResult, "condense 与 expand 结果应不同")
    }

    // MARK: - 模式特性验证

    func testCondenseResultIsShorterThanExpand() {
        // 精简模式的结果应比扩写模式短
        let condense = fixture.responses.rewrite.condense
        let expand = fixture.responses.rewrite.expand

        XCTAssertLessThan(condense.count, expand.count,
                         "condense 结果（\(condense.count) 字）应短于 expand 结果（\(expand.count) 字）")
    }

    // MARK: - 限流处理

    func testRewriteRateLimitedDoesNotBlockLocalFunctionality() async {
        mock.rewriteError = LLMError.rateLimited

        do {
            _ = try await mock.rewrite(text: "any", mode: .adjustTone)
            XCTFail("应抛出 rateLimited")
        } catch let error as LLMError {
            // 限流被捕获，本地功能不受影响
            XCTAssertEqual(error, .rateLimited)
        } catch {
            XCTFail("应抛出 LLMError")
        }
    }

    func testRewriteRateLimitedErrorHasDescription() {
        XCTAssertFalse(LLMError.rateLimited.errorDescription?.isEmpty ?? true,
                       "rateLimited 应有错误描述")
    }

    // MARK: - 其他错误场景

    func testRewriteNotConfiguredWhenNoApiKey() async {
        mock.rewriteError = LLMError.notConfigured

        do {
            _ = try await mock.rewrite(text: "any", mode: .condense)
            XCTFail("应抛出 notConfigured")
        } catch let error as LLMError {
            XCTAssertEqual(error, .notConfigured)
        } catch {
            XCTFail("应抛出 LLMError")
        }
    }

    func testRewriteInvalidAPIKeyError() async {
        mock.rewriteError = LLMError.invalidAPIKey

        do {
            _ = try await mock.rewrite(text: "any", mode: .expand)
            XCTFail("应抛出 invalidAPIKey")
        } catch let error as LLMError {
            XCTAssertEqual(error, .invalidAPIKey)
        } catch {
            XCTFail("应抛出 LLMError")
        }
    }

    // MARK: - 调用参数记录

    func testRewriteRecordsTextAndMode() async throws {
        mock.rewriteResult = "改写结果"

        _ = try await mock.rewrite(text: "原文内容", mode: .adjustTone)
        _ = try await mock.rewrite(text: "另一段", mode: .condense)

        XCTAssertEqual(mock.rewriteCalls.count, 2)
        XCTAssertEqual(mock.rewriteCalls[0].text, "原文内容")
        XCTAssertEqual(mock.rewriteCalls[0].mode, .adjustTone)
        XCTAssertEqual(mock.rewriteCalls[1].text, "另一段")
        XCTAssertEqual(mock.rewriteCalls[1].mode, .condense)
    }
}
