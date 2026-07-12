@testable import ClipMind
import XCTest

final class ClipItemModelTests: XCTestCase {
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // MARK: - ContentType

    func testContentTypeAllCases() {
        XCTAssertEqual(ContentType.allCases.count, 11)
        XCTAssertEqual(ContentType.code.rawValue, "code")
        XCTAssertEqual(ContentType.link.rawValue, "link")
        XCTAssertEqual(ContentType.error.rawValue, "error")
        XCTAssertEqual(ContentType.article.rawValue, "article")
        XCTAssertEqual(ContentType.todo.rawValue, "todo")
        XCTAssertEqual(ContentType.meeting.rawValue, "meeting")
        XCTAssertEqual(ContentType.translation.rawValue, "translation")
        XCTAssertEqual(ContentType.requirement.rawValue, "requirement")
        XCTAssertEqual(ContentType.apiDoc.rawValue, "api_doc")
        XCTAssertEqual(ContentType.englishDoc.rawValue, "english_doc")
        XCTAssertEqual(ContentType.other.rawValue, "other")
    }

    func testContentTypeCodableRoundTrip() throws {
        for type in ContentType.allCases {
            let data = try encoder.encode(type)
            let decoded = try decoder.decode(ContentType.self, from: data)
            XCTAssertEqual(decoded, type)
        }
    }

    // MARK: - ClipContent

    func testClipContentTextRoundTrip() throws {
        let original = ClipContent.text("Hello, ClipMind!")
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(ClipContent.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testClipContentImageRoundTrip() throws {
        let original = ClipContent.image(Data([0x89, 0x50, 0x4E, 0x47]))
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(ClipContent.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testClipContentFilePathRoundTrip() throws {
        let original = ClipContent.filePath([
            URL(fileURLWithPath: "/tmp/file1.txt"),
            URL(fileURLWithPath: "/tmp/file2.txt")
        ])
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(ClipContent.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - TodoItem

    func testTodoItemRoundTrip() throws {
        let original = TodoItem(
            id: UUID(),
            task: "完成数据模型",
            assignee: "张三",
            dueDate: "明天下午"
        )
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(TodoItem.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testTodoItemOptionalFields() throws {
        let original = TodoItem(
            id: UUID(),
            task: "简单任务",
            assignee: nil,
            dueDate: nil
        )
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(TodoItem.self, from: data)
        XCTAssertEqual(decoded, original)
        XCTAssertNil(decoded.assignee)
        XCTAssertNil(decoded.dueDate)
    }

    // MARK: - ClipItem

    func testClipItemTextRoundTrip() throws {
        let original = ClipItem(
            id: UUID(),
            content: .text("测试文本"),
            contentType: .article,
            sourceApp: "com.test.app",
            sourceAppName: "TestApp",
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            summary: "摘要",
            translation: "translation",
            rewrite: "rewrite",
            todos: [TodoItem(id: UUID(), task: "task", assignee: nil, dueDate: nil)],
            embeddings: [0.1, 0.2, 0.3]
        )
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(ClipItem.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testClipItemImageRoundTrip() throws {
        let original = ClipItem(
            id: UUID(),
            content: .image(Data([0xFF, 0xD8, 0xFF])),
            contentType: .other,
            sourceApp: "com.test.app",
            sourceAppName: "TestApp",
            timestamp: Date(),
            summary: nil,
            translation: nil,
            rewrite: nil,
            todos: nil,
            embeddings: nil
        )
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(ClipItem.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testClipItemFilePathRoundTrip() throws {
        let original = ClipItem(
            id: UUID(),
            content: .filePath([URL(fileURLWithPath: "/Users/test/file.pdf")]),
            contentType: .other,
            sourceApp: "com.test.app",
            sourceAppName: "TestApp",
            timestamp: Date(),
            summary: nil,
            translation: nil,
            rewrite: nil,
            todos: nil,
            embeddings: nil
        )
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(ClipItem.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testClipItemFactoryMethods() {
        let textItem = ClipItem.makeText(
            "hello",
            contentType: .code,
            sourceApp: "com.test",
            sourceAppName: "Test"
        )
        if case .text(let value) = textItem.content {
            XCTAssertEqual(value, "hello")
        } else {
            XCTFail("Expected text content")
        }

        let imageItem = ClipItem.makeImage(
            Data([0x01]),
            contentType: .other,
            sourceApp: "com.test",
            sourceAppName: "Test"
        )
        if case .image(let value) = imageItem.content {
            XCTAssertEqual(value, Data([0x01]))
        } else {
            XCTFail("Expected image content")
        }

        let fileItem = ClipItem.makeFilePath(
            [URL(fileURLWithPath: "/tmp/test")],
            contentType: .other,
            sourceApp: "com.test",
            sourceAppName: "Test"
        )
        if case .filePath(let value) = fileItem.content {
            XCTAssertEqual(value, [URL(fileURLWithPath: "/tmp/test")])
        } else {
            XCTFail("Expected filePath content")
        }
    }

    // MARK: - AppSettings

    func testAppSettingsDefaults() {
        let settings = AppSettings()
        XCTAssertNil(settings.apiProvider)
        XCTAssertNil(settings.apiKey)
        XCTAssertTrue(settings.sensitiveDetectionEnabled)
        XCTAssertTrue(settings.appBlacklist.isEmpty)
        XCTAssertTrue(settings.autoCleanupEnabled)
        XCTAssertEqual(settings.cleanupDays, 30)
        XCTAssertTrue(settings.launchAtLogin)
        XCTAssertEqual(settings.hotkey, "cmd+shift+v")
    }

    func testAppSettingsRoundTrip() throws {
        let original = AppSettings(
            apiProvider: .zhipu,
            apiKey: "secret-key",
            sensitiveDetectionEnabled: false,
            appBlacklist: ["com.test.app"],
            autoCleanupEnabled: false,
            cleanupDays: 7,
            launchAtLogin: false,
            hotkey: "ctrl+shift+c"
        )
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(AppSettings.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testAppSettingsDefaultRoundTrip() throws {
        let original = AppSettings()
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(AppSettings.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - APIProvider

    func testAPIProviderAllCases() {
        XCTAssertEqual(APIProvider.allCases.count, 4)
        XCTAssertEqual(APIProvider.openai.rawValue, "openai")
        XCTAssertEqual(APIProvider.zhipu.rawValue, "zhipu")
        XCTAssertEqual(APIProvider.qianwen.rawValue, "qianwen")
        XCTAssertEqual(APIProvider.deepseek.rawValue, "deepseek")
    }

    // MARK: - RewriteMode

    func testRewriteModeAllCases() {
        XCTAssertEqual(RewriteMode.allCases.count, 3)
        XCTAssertEqual(RewriteMode.adjustTone.rawValue, "adjust_tone")
        XCTAssertEqual(RewriteMode.condense.rawValue, "condense")
        XCTAssertEqual(RewriteMode.expand.rawValue, "expand")
    }

    // MARK: - BlacklistEntry

    // swiftlint:disable:next inclusive_language
    func testBlacklistEntryRoundTrip() throws {
        let original = BlacklistEntry(
            id: UUID(),
            bundleId: "com.example.app",
            appName: "ExampleApp",
            addedAt: Date(timeIntervalSince1970: 1_700_000_000),
            isDefault: true
        )
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(BlacklistEntry.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}
