import AppKit
import XCTest

@testable import ClipMind

final class ClipboardReplacerTests: XCTestCase
{
    private var pasteboard: NSPasteboard!
    private var suppressor: SelfWriteSuppressor!
    private var replacer: ClipboardReplacer!

    override func setUpWithError() throws
    {
        pasteboard = NSPasteboard(name: .init("test-\(UUID().uuidString)"))
        pasteboard.clearContents()
        suppressor = SelfWriteSuppressor()
        replacer = ClipboardReplacer(pasteboard: pasteboard, suppressor: suppressor)
    }

    // MARK: - TC-UT-50：成功替换剪贴板（D5 changeCount 匹配）

    func testReplaceSuccess() throws
    {
        pasteboard.clearContents()
        pasteboard.setString("original", forType: .string)
        let changeCount = pasteboard.changeCount

        let result = replacer.replace(with: "/path/to/file.md", expectedChangeCount: changeCount)

        XCTAssertTrue(result, "changeCount 匹配时应成功替换")
        XCTAssertEqual(pasteboard.string(forType: .string), "/path/to/file.md")
    }

    // MARK: - TC-UT-51：changeCount 不匹配时拒绝替换（D5 前置条件）

    func testReplaceRejectedWhenChangeCountMismatch() throws
    {
        pasteboard.clearContents()
        pasteboard.setString("original", forType: .string)

        let result = replacer.replace(
            with: "/path/to/file.md",
            expectedChangeCount: pasteboard.changeCount + 999
        )

        XCTAssertFalse(result, "changeCount 不匹配时应拒绝替换")
        XCTAssertEqual(pasteboard.string(forType: .string), "original", "原内容应未被修改")
    }

    // MARK: - TC-UT-52：替换后调用 markSelfWrite（D4）

    func testMarkSelfWriteAfterReplace() throws
    {
        pasteboard.clearContents()
        let changeCount = pasteboard.changeCount

        _ = replacer.replace(with: "/path/to/file.md", expectedChangeCount: changeCount)

        let newChangeCount = pasteboard.changeCount
        XCTAssertTrue(suppressor.checkAndReset(changeCount: newChangeCount), "应标记新的 changeCount")
    }

    // MARK: - F2.1.2：替换剪贴板时保留原始文本为 HTML 格式

    /// 验证替换剪贴板后，原始文本作为 HTML 格式保留，让其他剪贴板 app 能捕获到原文。
    func testReplacePreservesOriginalTextAsHTML() throws
    {
        pasteboard.clearContents()
        pasteboard.setString("原始复制内容", forType: .string)
        let changeCount = pasteboard.changeCount

        let result = replacer.replace(
            with: "/path/to/file.md",
            originalText: "原始复制内容",
            expectedChangeCount: changeCount
        )

        XCTAssertTrue(result, "changeCount 匹配时应成功替换")
        XCTAssertEqual(pasteboard.string(forType: .string), "/path/to/file.md", "文件路径应作为纯文本主格式")
        let htmlContent = pasteboard.string(forType: .html)
        XCTAssertNotNil(htmlContent, "应写入 HTML 格式保留原始文本")
        XCTAssertTrue(htmlContent?.contains("原始复制内容") ?? false, "HTML 内容应包含原始文本")
    }

    /// 验证原始文本中 HTML 特殊字符被正确转义。
    func testReplacePreservesOriginalTextWithHtmlSpecialCharacters() throws
    {
        pasteboard.clearContents()
        let changeCount = pasteboard.changeCount

        _ = replacer.replace(
            with: "/path/to/file.md",
            originalText: "<script>alert('xss')</script> & <b>bold</b>",
            expectedChangeCount: changeCount
        )

        let htmlContent = pasteboard.string(forType: .html)
        XCTAssertNotNil(htmlContent, "应写入 HTML 格式")
        XCTAssertTrue(htmlContent?.contains("&lt;script&gt;") ?? false, "应转义 < 为 &lt;")
        XCTAssertTrue(htmlContent?.contains("&lt;b&gt;") ?? false, "应转义 HTML 标签")
        XCTAssertTrue(htmlContent?.contains("&amp;") ?? false, "应转义 & 为 &amp;")
        XCTAssertFalse(htmlContent?.contains("<script>") ?? true, "不应包含未转义的 <script>")
    }

    /// 验证 originalText 为 nil 时，仅写入文件路径（向后兼容）。
    func testReplaceWithNilOriginalTextOnlyWritesPath() throws
    {
        pasteboard.clearContents()
        pasteboard.setString("原内容", forType: .string)
        let changeCount = pasteboard.changeCount

        _ = replacer.replace(
            with: "/path/to/file.md",
            originalText: nil,
            expectedChangeCount: changeCount
        )

        XCTAssertEqual(pasteboard.string(forType: .string), "/path/to/file.md", "文件路径应为纯文本")
        XCTAssertNil(pasteboard.string(forType: .html), "originalText 为 nil 时不应写入 HTML")
    }

    /// 验证 originalText 为空字符串时，仅写入文件路径。
    func testReplaceWithEmptyOriginalTextOnlyWritesPath() throws
    {
        pasteboard.clearContents()
        let changeCount = pasteboard.changeCount

        _ = replacer.replace(
            with: "/path/to/file.md",
            originalText: "",
            expectedChangeCount: changeCount
        )

        XCTAssertEqual(pasteboard.string(forType: .string), "/path/to/file.md", "文件路径应为纯文本")
        XCTAssertNil(pasteboard.string(forType: .html), "originalText 为空时不应写入 HTML")
    }

    /// 验证保留原始文本时也正确标记 markSelfWrite。
    func testReplaceWithOriginalTextMarksSelfWrite() throws
    {
        pasteboard.clearContents()
        let changeCount = pasteboard.changeCount

        _ = replacer.replace(
            with: "/path/to/file.md",
            originalText: "原始内容",
            expectedChangeCount: changeCount
        )

        let newChangeCount = pasteboard.changeCount
        XCTAssertTrue(suppressor.checkAndReset(changeCount: newChangeCount), "保留原文时也应标记新的 changeCount")
    }
}
