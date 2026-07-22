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
}
