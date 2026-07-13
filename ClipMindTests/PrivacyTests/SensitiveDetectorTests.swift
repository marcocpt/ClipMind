@testable import ClipMind
import Foundation
import XCTest

/// 敏感样本 fixture 的 Codable 结构
private struct SensitiveSamples: Codable {
    struct Sample: Codable {
        let text: String
        let type: String?
        let isSensitive: Bool
    }
    let samples: [Sample]
}

/// SensitiveDetector 单元测试（T3.1）
final class SensitiveDetectorTests: XCTestCase {
    /// 测试用 UserDefaults（隔离标准 UserDefaults）
    private var testDefaults: UserDefaults!
    private var testSuiteName: String!
    private var detector: SensitiveDetector!

    // MARK: - 生命周期

    override func setUpWithError() throws {
        testSuiteName = "SensitiveDetectorTests-\(UUID().uuidString)"
        testDefaults = UserDefaults(suiteName: testSuiteName)!
        // 默认不设置 key，使用默认值 true（敏感识别开启）
        detector = SensitiveDetector(defaults: testDefaults)
    }

    override func tearDownWithError() throws {
        if let suiteName = testSuiteName {
            UserDefaults().removePersistentDomain(forName: suiteName)
        }
        testDefaults = nil
        testSuiteName = nil
        detector = nil
    }

    // MARK: - 密码模式检测

    func testPasswordPatternDetected() {
        let type: SensitiveType? = detector.detect("password=abc123")
        XCTAssertEqual(type, .password)

        let isSensitive: Bool = detector.detect("password: mypass123")
        XCTAssertTrue(isSensitive)

        let type2: SensitiveType? = detector.detect("password = secret123")
        XCTAssertEqual(type2, .password)
    }

    // MARK: - Token 格式检测

    func testTokenFormatDetected() {
        let skType: SensitiveType? = detector.detect("sk-proj-abcdefghijklmnopqrstuvwxyz0123456789")
        XCTAssertEqual(skType, .token)

        let ghpType: SensitiveType? = detector.detect("ghp_abcdefghijklmnopqrstuvwxyz0123456789")
        XCTAssertEqual(ghpType, .token)

        let bearerType: SensitiveType? = detector.detect("Bearer abcdefghijklmnopqrstuvwxyz0123456789")
        XCTAssertEqual(bearerType, .token)
    }

    // MARK: - 验证码检测

    func testVerificationCodeDetected() {
        let type6: SensitiveType? = detector.detect("123456")
        XCTAssertEqual(type6, .verificationCode)

        let type8: SensitiveType? = detector.detect("12345678")
        XCTAssertEqual(type8, .verificationCode)

        // 3 位数字不匹配验证码模式
        let notCode: SensitiveType? = detector.detect("123")
        XCTAssertNil(notCode)
    }

    // MARK: - 银行卡号（Luhn 有效）

    func testBankCardWithLuhnValid() {
        let type: SensitiveType? = detector.detect("4111111111111111")
        XCTAssertEqual(type, .bankCard)

        let isSensitive: Bool = detector.detect("4111111111111111")
        XCTAssertTrue(isSensitive)
    }

    // MARK: - 银行卡号（Luhn 无效）

    func testBankCardWithLuhnInvalid() {
        let type: SensitiveType? = detector.detect("4111111111111112")
        XCTAssertNil(type)

        let isSensitive: Bool = detector.detect("4111111111111112")
        XCTAssertFalse(isSensitive)
    }

    // MARK: - 身份证号（有效）

    func testIDCardValid() {
        let type: SensitiveType? = detector.detect("110101199001011237")
        XCTAssertEqual(type, .idCard)
    }

    // MARK: - 身份证号（无效）

    func testIDCardInvalid() {
        let type: SensitiveType? = detector.detect("110101199001011234")
        XCTAssertNil(type)
    }

    // MARK: - 敏感关键词检测

    func testSensitiveKeywordDetected() {
        let apiKeyType: SensitiveType? = detector.detect("api_key=xxx")
        XCTAssertEqual(apiKeyType, .sensitiveKeyword)

        let secretType: SensitiveType? = detector.detect("the secret value is hidden")
        XCTAssertEqual(secretType, .sensitiveKeyword)

        let tokenType: SensitiveType? = detector.detect("access_token=abc123")
        XCTAssertEqual(tokenType, .sensitiveKeyword)

        let privateKeyType: SensitiveType? = detector.detect("private_key=-----BEGIN")
        XCTAssertEqual(privateKeyType, .sensitiveKeyword)
    }

    // MARK: - 普通文本不检测

    func testNonSensitiveTextNotDetected() {
        let type: SensitiveType? = detector.detect("Hello, this is a normal text.")
        XCTAssertNil(type)

        let isSensitive: Bool = detector.detect("passion for coding")
        XCTAssertFalse(isSensitive)

        // 短 token 不应被检测
        let shortToken: SensitiveType? = detector.detect("sk-short")
        XCTAssertNil(shortToken)
    }

    // MARK: - 关闭敏感识别

    func testDisabledDetectionReturnsFalse() {
        testDefaults.set(false, forKey: SensitiveDetector.storageKey)

        let isSensitive: Bool = detector.detect("password=abc123")
        XCTAssertFalse(isSensitive)

        let type: SensitiveType? = detector.detect("password=abc123")
        XCTAssertNil(type)
    }

    // MARK: - Fixture 样本验证

    func testFixtureSamples() throws {
        let samples = try loadFixtureSamples()
        XCTAssertEqual(samples.count, 20, "fixture 应包含 20 条样本")

        for sample in samples {
            let type: SensitiveType? = detector.detect(sample.text)
            if sample.isSensitive {
                XCTAssertNotNil(type, "应检测为敏感: \(sample.text)")
                XCTAssertEqual(type?.rawValue, sample.type, "类型不匹配: \(sample.text)")
            } else {
                XCTAssertNil(type, "不应检测为敏感: \(sample.text)")
            }
        }
    }
}

// MARK: - Fixture 加载

private extension SensitiveDetectorTests {
    /// 从测试 bundle 加载 fixture 样本
    func loadFixtureSamples() throws -> [SensitiveSamples.Sample] {
        let bundle = Bundle(for: SensitiveDetectorTests.self)
        guard let url = bundle.url(forResource: "sensitive_samples", withExtension: "json") else {
            throw FixtureError.fileNotFound
        }
        let data = try Data(contentsOf: url)
        let fixture = try JSONDecoder().decode(SensitiveSamples.self, from: data)
        return fixture.samples
    }

    enum FixtureError: Error {
        case fileNotFound
    }
}
