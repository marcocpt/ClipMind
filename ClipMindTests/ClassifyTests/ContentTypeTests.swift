@testable import ClipMind
import XCTest

/// ContentType 分类测试。
///
/// 验证 ClassificationService 能正确识别各种内容类型，
/// 覆盖 AC-06（代码片段识别为 code）和 AC-07（报错日志识别为 error）。
final class ContentTypeTests: XCTestCase {
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

    // MARK: - code

    func testClassifySwiftCode() {
        let type = classifier.classify("func viewDidLoad() { super.viewDidLoad() }")
        XCTAssertEqual(type, .code, "Swift 代码应被识别为 code 类型")
    }

    func testClassifyPythonCode() {
        let type = classifier.classify("def calculate(x, y): return x + y")
        XCTAssertEqual(type, .code, "Python 代码应被识别为 code 类型")
    }

    func testClassifyJavaScriptCode() {
        let type = classifier.classify("const promise = new Promise((resolve, reject) => { })")
        XCTAssertEqual(type, .code, "JavaScript 代码应被识别为 code 类型")
    }

    // MARK: - link

    func testClassifyHttpsUrl() {
        let type = classifier.classify("https://www.github.com/user/repo")
        XCTAssertEqual(type, .link, "HTTPS URL 应被识别为 link 类型")
    }

    func testClassifyStackOverflowUrl() {
        let type = classifier.classify("https://stackoverflow.com/questions/123456/how-to-fix-bug")
        XCTAssertEqual(type, .link, "StackOverflow URL 应被识别为 link 类型")
    }

    // MARK: - error

    func testClassifySwiftError() {
        let type = classifier.classify("Fatal error: Unexpectedly found nil while unwrapping")
        XCTAssertEqual(type, .error, "Swift 报错应被识别为 error 类型")
    }

    func testClassifyPythonTraceback() {
        let type = classifier.classify("Traceback (most recent call last): File '<stdin>', line 1, in <module>")
        XCTAssertEqual(type, .error, "Python 堆栈报错应被识别为 error 类型")
    }

    func testClassifyTypeError() {
        let type = classifier.classify("TypeError: 'NoneType' object is not iterable")
        XCTAssertEqual(type, .error, "TypeError 应被识别为 error 类型")
    }

    // MARK: - todo

    func testClassifyTodoItem() {
        let type = classifier.classify("TODO: Fix the login bug before Friday")
        XCTAssertEqual(type, .todo, "TODO 项应被识别为 todo 类型")
    }

    func testClassifyCheckboxItem() {
        let type = classifier.classify("- [ ] Buy groceries: milk, bread, eggs")
        XCTAssertEqual(type, .todo, "Checkbox 项应被识别为 todo 类型")
    }

    // MARK: - meeting

    func testClassifyMeetingNotes() {
        let type = classifier.classify("Meeting notes: Discussed Q4 roadmap and team assignments")
        XCTAssertEqual(type, .meeting, "会议纪要应被识别为 meeting 类型")
    }

    // MARK: - translation

    func testClassifyTranslationPair() {
        let type = classifier.classify("Hello World -> Bonjour le Monde")
        XCTAssertEqual(type, .translation, "翻译对应应被识别为 translation 类型")
    }

    // MARK: - requirement

    func testClassifyUserStory() {
        let type = classifier.classify(
            "User Story: As a user, I want to login with email so that I can access my account"
        )
        XCTAssertEqual(type, .requirement, "用户故事应被识别为 requirement 类型")
    }

    // MARK: - apiDoc

    func testClassifyApiEndpoint() {
        let type = classifier.classify("GET /api/v1/users - Returns list of users. Parameters: limit, offset")
        XCTAssertEqual(type, .apiDoc, "API 端点文档应被识别为 apiDoc 类型")
    }

    // MARK: - englishDoc

    func testClassifyDocumentation() {
        let type = classifier.classify("Documentation: How to configure the application settings")
        XCTAssertEqual(type, .englishDoc, "英文文档应被识别为 englishDoc 类型")
    }

    // MARK: - other

    func testClassifyRandomTextReturnsOther() {
        let type = classifier.classify("12345 67890 abcdef")
        XCTAssertEqual(type, .other, "随机文本应被识别为 other 类型")
    }

    func testClassifyEmptyReturnsOther() {
        let type = classifier.classify("")
        XCTAssertEqual(type, .other, "空文本应被识别为 other 类型")
    }
}
