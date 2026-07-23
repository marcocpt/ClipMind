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

    // MARK: - TC-UT-31：特殊字符替换为下划线（D9 步骤 4，替换而非过滤）

    func testSpecialCharacterReplacement() throws
    {
        let generator = FileNameGenerator()
        let fileName = generator.generate(
            content: "hello/world:test*file",
            appName: "Safari",
            fileFormat: .plainText,
            fileNameLength: 50,
            timestamp: Date(timeIntervalSince1970: 1700000000)
        )

        XCTAssertFalse(fileName.contains("/"), "不应保留 /")
        XCTAssertFalse(fileName.contains(":"), "不应保留 :")
        XCTAssertFalse(fileName.contains("*"), "不应保留 *")
        XCTAssertTrue(fileName.hasSuffix(".txt"))
        XCTAssertEqual(fileName, "hello_world_test_file.txt", "应将特殊字符替换为 _ 而非删除")
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

    // MARK: - TC-UT-36：Markdown 格式符号替换为 _（D9 步骤 4 扩展字符集）

    func testMarkdownSymbolsReplacement() throws
    {
        let generator = FileNameGenerator()
        let fileName = generator.generate(
            content: "# 标题 `代码` ~删除~ [链接]",
            appName: "Safari",
            fileFormat: .markdown,
            fileNameLength: 50,
            timestamp: Date(timeIntervalSince1970: 1700000000)
        )

        XCTAssertFalse(fileName.contains("#"), "应替换 #")
        XCTAssertFalse(fileName.contains("`"), "应替换反引号")
        XCTAssertFalse(fileName.contains("~"), "应替换 ~")
        XCTAssertFalse(fileName.contains("["), "应替换 [")
        XCTAssertFalse(fileName.contains("]"), "应替换 ]")
        XCTAssertTrue(fileName.contains("标题"), "应保留中文")
        XCTAssertTrue(fileName.contains("代码"), "应保留中文")
        XCTAssertTrue(fileName.hasSuffix(".md"))
    }

    // MARK: - TC-UT-37：Shell 特殊字符替换为 _（D9 步骤 4 扩展字符集）

    func testShellSpecialCharsReplacement() throws
    {
        let generator = FileNameGenerator()
        let fileName = generator.generate(
            content: "test%var&cmd;dir$home(arg){val}'str'!end",
            appName: "Safari",
            fileFormat: .plainText,
            fileNameLength: 60,
            timestamp: Date(timeIntervalSince1970: 1700000000)
        )

        XCTAssertFalse(fileName.contains("%"), "应替换 %")
        XCTAssertFalse(fileName.contains("&"), "应替换 &")
        XCTAssertFalse(fileName.contains(";"), "应替换 ;")
        XCTAssertFalse(fileName.contains("$"), "应替换 $")
        XCTAssertFalse(fileName.contains("("), "应替换 (")
        XCTAssertFalse(fileName.contains(")"), "应替换 )")
        XCTAssertFalse(fileName.contains("{"), "应替换 {")
        XCTAssertFalse(fileName.contains("}"), "应替换 }")
        XCTAssertFalse(fileName.contains("'"), "应替换 '")
        XCTAssertFalse(fileName.contains("!"), "应替换 !")
        XCTAssertTrue(fileName.hasSuffix(".txt"))
    }

    // MARK: - TC-UT-38：中文标点替换为 _（D9 步骤 4 扩展字符集）

    func testChinesePunctuationReplacement() throws
    {
        let generator = FileNameGenerator()
        let fileName = generator.generate(
            content: "你好，世界！测试？答案：是；完成（ yes ）【记】《书》—续…",
            appName: "Safari",
            fileFormat: .markdown,
            fileNameLength: 80,
            timestamp: Date(timeIntervalSince1970: 1700000000)
        )

        XCTAssertFalse(fileName.contains("，"), "应替换中文逗号")
        XCTAssertFalse(fileName.contains("！"), "应替换中文感叹号")
        XCTAssertFalse(fileName.contains("？"), "应替换中文问号")
        XCTAssertFalse(fileName.contains("："), "应替换中文冒号")
        XCTAssertFalse(fileName.contains("；"), "应替换中文分号")
        XCTAssertFalse(fileName.contains("（"), "应替换中文左括号")
        XCTAssertFalse(fileName.contains("）"), "应替换中文右括号")
        XCTAssertFalse(fileName.contains("【"), "应替换【")
        XCTAssertFalse(fileName.contains("】"), "应替换】")
        XCTAssertFalse(fileName.contains("《"), "应替换《")
        XCTAssertFalse(fileName.contains("》"), "应替换》")
        XCTAssertTrue(fileName.contains("你好"), "应保留中文")
        XCTAssertTrue(fileName.contains("世界"), "应保留中文")
        XCTAssertTrue(fileName.hasSuffix(".md"))
    }

    // MARK: - TC-UT-39：英文标点替换为 _（不含 . 和 -，D9 步骤 4 扩展字符集）

    func testEnglishPunctuationReplacement() throws
    {
        let generator = FileNameGenerator()
        let fileName = generator.generate(
            content: "hello, world! test? yes: no; done(ok)",
            appName: "Safari",
            fileFormat: .plainText,
            fileNameLength: 60,
            timestamp: Date(timeIntervalSince1970: 1700000000)
        )

        XCTAssertFalse(fileName.contains(","), "应替换英文逗号")
        XCTAssertFalse(fileName.contains("!"), "应替换英文感叹号")
        XCTAssertFalse(fileName.contains("?"), "应替换英文问号")
        XCTAssertFalse(fileName.contains(":"), "应替换英文冒号")
        XCTAssertFalse(fileName.contains(";"), "应替换英文分号")
        XCTAssertFalse(fileName.contains("("), "应替换英文左括号")
        XCTAssertFalse(fileName.contains(")"), "应替换英文右括号")
        XCTAssertTrue(fileName.contains("hello"), "应保留英文")
        XCTAssertTrue(fileName.contains("world"), "应保留英文")
    }

    // MARK: - TC-UT-40：连续特殊字符折叠为单个 _（D9 步骤 4.5）

    func testConsecutiveUnderscoreCollapse() throws
    {
        let generator = FileNameGenerator()
        let fileName = generator.generate(
            content: "a###b,,,c!!!d",
            appName: "Safari",
            fileFormat: .markdown,
            fileNameLength: 50,
            timestamp: Date(timeIntervalSince1970: 1700000000)
        )

        XCTAssertFalse(fileName.contains("__"), "连续 _ 应折叠为单个")
        XCTAssertEqual(fileName, "a_b_c_d.md", "连续特殊字符应折叠为单个 _")
    }

    // MARK: - TC-UT-41：首尾 _ 去除（D9 步骤 5 扩展）

    func testLeadingTrailingUnderscoreTrim() throws
    {
        let generator = FileNameGenerator()
        let fileName = generator.generate(
            content: "###hello###",
            appName: "Safari",
            fileFormat: .markdown,
            fileNameLength: 50,
            timestamp: Date(timeIntervalSince1970: 1700000000)
        )

        XCTAssertFalse(fileName.hasPrefix("_"), "应去除首部 _")
        XCTAssertFalse(fileName.hasSuffix("_.md"), "应去除尾部 _（扩展名前）")
        XCTAssertEqual(fileName, "hello.md", "首尾 _ 应被修剪")
    }

    // MARK: - TC-UT-42：全特殊字符使用 clip-{timestamp} 备用名（D9 步骤 6）

    func testAllSpecialCharsUsesFallback() throws
    {
        let generator = FileNameGenerator()
        let fileName = generator.generate(
            content: "###***???,,,",
            appName: "Safari",
            fileFormat: .markdown,
            fileNameLength: 50,
            timestamp: Date(timeIntervalSince1970: 1700000000)
        )

        XCTAssertTrue(fileName.hasPrefix("clip-"), "全特殊字符应使用 clip-{timestamp} 备用名")
        XCTAssertTrue(fileName.hasSuffix(".md"), "应包含 .md 扩展名")
    }

    // MARK: - TC-UT-43：点与连字符保留（文件名常用字符）

    func testDotAndHyphenPreserved() throws
    {
        let generator = FileNameGenerator()
        let fileName = generator.generate(
            content: "v1.2-release-notes",
            appName: "Safari",
            fileFormat: .markdown,
            fileNameLength: 50,
            timestamp: Date(timeIntervalSince1970: 1700000000)
        )

        XCTAssertTrue(fileName.contains("."), "应保留点（版本号）")
        XCTAssertTrue(fileName.contains("-"), "应保留连字符")
        XCTAssertEqual(fileName, "v1.2-release-notes.md", "点与连字符应保留")
    }

    // MARK: - TC-UT-44：空格保留（步骤 2 已折叠，步骤 4 不替换空格）

    func testSpacePreserved() throws
    {
        let generator = FileNameGenerator()
        let fileName = generator.generate(
            content: "hello world test",
            appName: "Safari",
            fileFormat: .markdown,
            fileNameLength: 50,
            timestamp: Date(timeIntervalSince1970: 1700000000)
        )

        XCTAssertTrue(fileName.contains(" "), "应保留空格")
        XCTAssertFalse(fileName.contains("  "), "连续空格应折叠为单个")
        XCTAssertEqual(fileName, "hello world test.md", "空格应保留")
    }

    // MARK: - TC-UT-45：混合内容（中文+英文+标点+Markdown+Shell）

    func testMixedContentReplacement() throws
    {
        let generator = FileNameGenerator()
        let fileName = generator.generate(
            content: "Swift 5.7 #init() { self.value = $var } // 注释，测试",
            appName: "Safari",
            fileFormat: .markdown,
            fileNameLength: 80,
            timestamp: Date(timeIntervalSince1970: 1700000000)
        )

        XCTAssertFalse(fileName.contains("#"), "应替换 #")
        XCTAssertFalse(fileName.contains("("), "应替换 (")
        XCTAssertFalse(fileName.contains(")"), "应替换 )")
        XCTAssertFalse(fileName.contains("{"), "应替换 {")
        XCTAssertFalse(fileName.contains("}"), "应替换 }")
        XCTAssertFalse(fileName.contains("$"), "应替换 $")
        XCTAssertFalse(fileName.contains("，"), "应替换中文逗号")
        XCTAssertTrue(fileName.contains("Swift"), "应保留英文")
        XCTAssertTrue(fileName.contains("5.7"), "应保留版本号中的点")
        XCTAssertTrue(fileName.contains("注释"), "应保留中文")
        XCTAssertTrue(fileName.contains("测试"), "应保留中文")
        XCTAssertFalse(fileName.contains("__"), "连续 _ 应折叠")
    }
}
