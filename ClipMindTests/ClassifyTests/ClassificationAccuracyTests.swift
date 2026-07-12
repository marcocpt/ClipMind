@testable import ClipMind
import XCTest

/// 分类准确率测试。
///
/// 验证 ClassificationService 的整体分类准确率满足 AC-05（≥ 80%）。
/// 使用内联测试样本集，覆盖 11 种内容类型。T1.5 将补充完整的 220 条样本集。
final class ClassificationAccuracyTests: XCTestCase {
    /// 误分类样本记录
    private struct MisclassifiedSample {
        let expected: ContentType
        let actual: ContentType
        let text: String
    }

    private var embeddingService: LocalEmbeddingService!
    private var classifier: ClassificationService!

    override func setUp() {
        super.setUp()
        embeddingService = LocalEmbeddingService()
        classifier = ClassificationService(embeddingService: embeddingService)
    }

    override func tearDown() {
        classifier = nil
        embeddingService = nil
        super.tearDown()
    }

    /// 内联测试样本集：11 种类型 × 3 条样本 = 33 条。
    /// T1.5 将替换为 220 条 JSON 样本集。
    private static let samples: [(type: ContentType, text: String)] = [
        // code
        (.code, "func viewDidLoad() { super.viewDidLoad() }"),
        (.code, "def calculate(x, y): return x + y"),
        (.code, "const promise = new Promise((resolve, reject) => { })"),
        // link
        (.link, "https://www.github.com/user/repo"),
        (.link, "https://stackoverflow.com/questions/123456/how-to-fix-bug"),
        (.link, "https://developer.apple.com/documentation/swift"),
        // error
        (.error, "Fatal error: Unexpectedly found nil while unwrapping"),
        (.error, "Traceback (most recent call last): File '<stdin>', line 1, in <module>"),
        (.error, "TypeError: 'NoneType' object is not iterable"),
        // article
        (.article, "The future of artificial intelligence in everyday applications"),
        (.article, "How to improve your productivity with time management techniques"),
        (.article, "Understanding the basics of machine learning and neural networks"),
        // todo
        (.todo, "TODO: Fix the login bug before Friday"),
        (.todo, "- [ ] Buy groceries: milk, bread, eggs"),
        (.todo, "Task: Complete the quarterly report by end of month"),
        // meeting
        (.meeting, "Meeting notes: Discussed Q4 roadmap and team assignments"),
        (.meeting, "Standup: Yesterday finished API integration, today working on tests"),
        (.meeting, "Sprint planning: Committed to 5 user stories for next sprint"),
        // translation
        (.translation, "Hello World -> Bonjour le Monde"),
        (.translation, "Good morning -> Buenos dias"),
        (.translation, "English to Chinese: Artificial Intelligence -> 人工智能"),
        // requirement
        (.requirement, "User Story: As a user, I want to login with email so that I can access my account"),
        (.requirement, "Requirement: The system shall support up to 1000 concurrent users"),
        (.requirement, "Acceptance Criteria: Given valid credentials, when user clicks login, then redirect"),
        // apiDoc
        (.apiDoc, "GET /api/v1/users - Returns list of users. Parameters: limit, offset"),
        (.apiDoc, "POST /api/v1/auth/login - Authenticate user. Body: {email, password}"),
        (.apiDoc, "DELETE /api/v1/items/{id} - Delete item by ID. Returns 204 No Content"),
        // englishDoc
        (.englishDoc, "Documentation: How to configure the application settings"),
        (.englishDoc, "README: This project demonstrates a clipboard manager for macOS"),
        (.englishDoc, "Tutorial: Learn how to build a REST API with Node.js and Express"),
        // other
        (.other, "12345 67890 abcdef"),
        (.other, "Lorem ipsum dolor sit amet consectetur adipiscing elit"),
        (.other, "Mixed content with numbers 123 and symbols @#$%")
    ]

    func testClassificationAccuracyMeetsThreshold() {
        var correctCount = 0
        let totalCount = Self.samples.count
        var misclassified: [MisclassifiedSample] = []

        for sample in Self.samples {
            let actual = classifier.classify(sample.text)
            if actual == sample.type {
                correctCount += 1
            } else {
                misclassified.append(
                    MisclassifiedSample(expected: sample.type, actual: actual, text: sample.text)
                )
            }
        }

        let accuracy = Double(correctCount) / Double(totalCount)
        LogCategory.classify.info("Classification accuracy: \(accuracy) (\(correctCount)/\(totalCount))")

        XCTAssertGreaterThanOrEqual(
            accuracy, 0.8,
            "分类准确率应 ≥ 80%，实际 \(accuracy)（\(correctCount)/\(totalCount)）。误分类: \(misclassified)"
        )
    }

    func testClassifyWithScoreReturnsValidScore() {
        let result = classifier.classifyWithScore("func viewDidLoad() { super.viewDidLoad() }")
        XCTAssertEqual(result.type, .code)
        XCTAssertGreaterThan(result.score, 0.2, "代码分类的置信度应高于阈值")
    }

    func testClassifyWithScoreReturnsZeroForEmptyText() {
        let result = classifier.classifyWithScore("")
        XCTAssertEqual(result.type, .other)
        XCTAssertEqual(result.score, 0.0, accuracy: 0.001)
    }
}
