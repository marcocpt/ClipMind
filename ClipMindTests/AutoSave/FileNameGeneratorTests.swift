import XCTest

@testable import ClipMind

final class FileNameGeneratorTests: XCTestCase
{
    // MARK: - TC-UT-30：基础文件名生成（D9 8 步）

    func testBasicFileNameGeneration() throws
    {
        let generator = FileNameGenerator()
        let fileName = generator.generate(
            content: "hello world",
            appName: "Safari",
            fileFormat: .markdown,
            fileNameLength: 20,
            timestamp: Date(timeIntervalSince1970: 1700000000)
        )

        XCTAssertEqual(fileName, "hello world.md", "应取内容前缀并添加扩展名（D9 步骤 3+7）")
    }

    // MARK: - TC-UT-31：非法字符过滤（D9 步骤 4，过滤而非替换）

    func testIllegalCharacterFiltering() throws
    {
        let generator = FileNameGenerator()
        let fileName = generator.generate(
            content: "hello/world:test*file",
            appName: "Safari",
            fileFormat: .plainText,
            fileNameLength: 50,
            timestamp: Date(timeIntervalSince1970: 1700000000)
        )

        XCTAssertFalse(fileName.contains("/"), "应过滤 /")
        XCTAssertFalse(fileName.contains(":"), "应过滤 :")
        XCTAssertFalse(fileName.contains("*"), "应过滤 *")
        XCTAssertTrue(fileName.hasSuffix(".txt"))
        XCTAssertEqual(fileName, "helloworldtestfile.txt", "应过滤非法字符后拼接")
    }

    // MARK: - TC-UT-32：空内容使用 clip-{timestamp}（D9 步骤 6）

    func testEmptyContentUsesClipTimestamp() throws
    {
        let generator = FileNameGenerator()
        let fileName = generator.generate(
            content: "   ",
            appName: "Safari",
            fileFormat: .markdown,
            fileNameLength: 20,
            timestamp: Date(timeIntervalSince1970: 1700000000)
        )

        XCTAssertTrue(fileName.hasPrefix("clip-"), "空内容应使用 clip-{timestamp} 备用名")
        XCTAssertTrue(fileName.hasSuffix(".md"), "应包含 .md 扩展名")
    }

    // MARK: - TC-UT-33：取前 N 字符（D9 步骤 3，按 Character 组合字符簇）

    func testPrefixLengthLimit() throws
    {
        let generator = FileNameGenerator()
        let longContent = String(repeating: "a", count: 100)
        let fileName = generator.generate(
            content: longContent,
            appName: "Safari",
            fileFormat: .markdown,
            fileNameLength: 20,
            timestamp: Date(timeIntervalSince1970: 1700000000)
        )

        // 文件名 = 20 字符前缀 + ".md" = 23 字符
        XCTAssertEqual(fileName.count, 23, "应取前 20 字符 + 扩展名")
        XCTAssertTrue(fileName.hasSuffix(".md"))
    }

    // MARK: - TC-UT-34：换行与空白标准化（D9 步骤 2，CRLF→LF，连续空白折叠）

    func testWhitespaceNormalization() throws
    {
        let generator = FileNameGenerator()
        let fileName = generator.generate(
            content: "hello\r\n\r\n   world",
            appName: "Safari",
            fileFormat: .markdown,
            fileNameLength: 50,
            timestamp: Date(timeIntervalSince1970: 1700000000)
        )

        XCTAssertFalse(fileName.contains("\r"), "应将 CRLF 转为 LF")
        XCTAssertFalse(fileName.contains("\n"), "应过滤换行符（步骤 4）")
        XCTAssertFalse(fileName.contains("  "), "连续空白应折叠为单个空格")
        XCTAssertTrue(fileName.hasSuffix(".md"))
    }

    // MARK: - TC-UT-35：首尾空白与首尾的点去除（D9 步骤 5）

    func testTrimLeadingTrailingDotsAndWhitespace() throws
    {
        let generator = FileNameGenerator()
        let fileName = generator.generate(
            content: "  .hello.  ",
            appName: "Safari",
            fileFormat: .markdown,
            fileNameLength: 50,
            timestamp: Date(timeIntervalSince1970: 1700000000)
        )

        XCTAssertFalse(fileName.hasPrefix("."), "应去除首尾的点")
        XCTAssertFalse(fileName.hasPrefix(" "), "应去除首尾空白")
        XCTAssertTrue(fileName.hasPrefix("hello"), "应保留内容")
        XCTAssertTrue(fileName.hasSuffix(".md"))
    }

    // MARK: - TC-UT-35b：中文保留（D9 步骤 4 保留中文，AC-10）

    func testChinesePreserved() throws
    {
        let generator = FileNameGenerator()
        let fileName = generator.generate(
            content: "你好世界 content",
            appName: "Safari",
            fileFormat: .markdown,
            fileNameLength: 50,
            timestamp: Date(timeIntervalSince1970: 1700000000)
        )

        XCTAssertTrue(fileName.contains("你好世界"), "应保留中文")
        XCTAssertTrue(fileName.hasSuffix(".md"))
    }
}
