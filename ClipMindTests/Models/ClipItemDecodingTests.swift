@testable import ClipMind
import XCTest

final class ClipItemDecodingTests: XCTestCase {
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    // MARK: - TC-F18-017 旧 JSON 无 isSample 字段解码默认 false

    func testDecodeOldJSONWithoutIsSample() throws {
        let oldJSON: [String: Any] = [
            "id": UUID().uuidString,
            "content": ["type": "text", "value": "旧数据"],
            "contentType": "article",
            "sourceApp": "com.test",
            "sourceAppName": "Test",
            "timestamp": "2026-07-14T10:00:00Z",
            "summary": NSNull(),
            "translation": NSNull(),
            "rewrite": NSNull(),
            "todos": NSNull(),
            "embeddings": NSNull()
        ]
        let data = try JSONSerialization.data(withJSONObject: oldJSON)

        let item = try decoder.decode(ClipItem.self, from: data)

        XCTAssertEqual(item.isSample, false, "旧 JSON 无 isSample 字段时默认 false")
    }

    // MARK: - TC-F18-018 新 JSON 含 isSample=true 解码正确

    func testDecodeNewJSONWithIsSampleTrue() throws {
        let newJSON: [String: Any] = [
            "id": UUID().uuidString,
            "content": ["type": "text", "value": "示例"],
            "contentType": "code",
            "sourceApp": "com.test",
            "sourceAppName": "Test",
            "timestamp": "2026-07-14T10:00:00Z",
            "summary": NSNull(),
            "translation": NSNull(),
            "rewrite": NSNull(),
            "todos": NSNull(),
            "embeddings": NSNull(),
            "isSample": true
        ]
        let data = try JSONSerialization.data(withJSONObject: newJSON)

        let item = try decoder.decode(ClipItem.self, from: data)

        XCTAssertEqual(item.isSample, true, "新 JSON 含 isSample=true 应正确解码")
    }

    // MARK: - TC-F18-019 编码包含 isSample 字段

    func testEncodeIncludesIsSampleField() throws {
        let item = ClipItem.makeText(
            "测试",
            contentType: .article,
            sourceApp: "com.test",
            sourceAppName: "Test",
            isSample: true
        )

        let data = try encoder.encode(item)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertNotNil(json?["isSample"], "编码后的 JSON 应包含 isSample key")
        XCTAssertEqual(json?["isSample"] as? Bool, true)
    }

    // MARK: - TC-F18-020 makeText 工厂方法默认 isSample=false

    func testMakeTextDefaultIsSampleFalse() {
        let item = ClipItem.makeText(
            "hello",
            contentType: .code,
            sourceApp: "com.test",
            sourceAppName: "Test"
        )

        XCTAssertEqual(item.isSample, false, "不传 isSample 时默认 false")
    }

    // MARK: - 补充：makeImage / makeFilePath 默认 isSample=false

    func testMakeImageDefaultIsSampleFalse() {
        let item = ClipItem.makeImage(
            Data([0x89]),
            contentType: .other,
            sourceApp: "com.test",
            sourceAppName: "Test"
        )

        XCTAssertEqual(item.isSample, false)
    }

    func testMakeFilePathDefaultIsSampleFalse() {
        let item = ClipItem.makeFilePath(
            [URL(fileURLWithPath: "/tmp/test")],
            contentType: .other,
            sourceApp: "com.test",
            sourceAppName: "Test"
        )

        XCTAssertEqual(item.isSample, false)
    }
}
