import XCTest

@testable import ClipMind

final class FilePathFormatterTests: XCTestCase
{
    private let formatter = FilePathFormatter()

    // MARK: - TC-UT-46：plainPath 格式

    func testPlainPathFormat() throws
    {
        let url = URL(fileURLWithPath: "/Users/test/Documents/Clips/hello.md")
        let result = formatter.format(url: url, format: .plainPath)
        XCTAssertEqual(result, "/Users/test/Documents/Clips/hello.md")
    }

    // MARK: - TC-UT-47：fileURI 格式（D16 URI 编码）

    func testFileURIFormat() throws
    {
        let url = URL(fileURLWithPath: "/Users/test/Documents/Clips/hello world.md")
        let result = formatter.format(url: url, format: .fileURI)
        XCTAssertEqual(result, "file:///Users/test/Documents/Clips/hello%20world.md")
    }

    // MARK: - TC-UT-48：markdownLink 格式（D16 URL 编码）

    func testMarkdownLinkFormat() throws
    {
        let url = URL(fileURLWithPath: "/Users/test/Documents/Clips/hello world.md")
        let result = formatter.format(url: url, format: .markdownLink)
        XCTAssertEqual(result, "[hello world.md](file:///Users/test/Documents/Clips/hello%20world.md)")
    }

    // MARK: - TC-UT-49：中文文件名 URI 编码

    func testChineseFileNameURIEncoding() throws
    {
        let url = URL(fileURLWithPath: "/Users/test/Documents/Clips/测试文件.md")
        let result = formatter.format(url: url, format: .fileURI)
        XCTAssertTrue(result.hasPrefix("file:///Users/test/Documents/Clips/"))
        XCTAssertTrue(result.contains(".md"))
        XCTAssertFalse(result.contains("测试文件"), "中文字符应被编码")
    }
}
