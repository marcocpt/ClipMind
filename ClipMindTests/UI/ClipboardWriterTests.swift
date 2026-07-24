import AppKit
@testable import ClipMind
import XCTest

final class ClipboardWriterTests: XCTestCase
{
    // MARK: - 写入文本成功

    func testWriteText_ReturnsTrue_AndWritesToPasteboard()
    {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("ClipMindTestPasteboard"))
        pasteboard.clearContents()
        let writer = ClipboardWriter(pasteboard: pasteboard)

        let success = writer.write(text: "测试文本内容")

        XCTAssertTrue(success, "写入文本应返回 true")
        let readString = pasteboard.string(forType: .string)
        XCTAssertEqual(readString, "测试文本内容", "剪贴板应包含写入的文本")
    }

    // MARK: - 写入空文本仍成功（不绕过敏感识别，敏感识别在捕获阶段处理）

    func testWriteText_EmptyString_ReturnsTrue()
    {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("ClipMindTestPasteboard"))
        pasteboard.clearContents()
        let writer = ClipboardWriter(pasteboard: pasteboard)

        let success = writer.write(text: "")

        XCTAssertTrue(success, "写入空文本应返回 true")
    }

    // MARK: - 写入后 changeCount 增加（验证写入确实生效）

    func testWriteText_IncreasesChangeCount()
    {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("ClipMindTestPasteboard"))
        pasteboard.clearContents()
        let writer = ClipboardWriter(pasteboard: pasteboard)

        let countBefore = pasteboard.changeCount
        _ = writer.write(text: "内容")
        let countAfter = pasteboard.changeCount

        XCTAssertGreaterThan(countAfter, countBefore, "写入后 changeCount 应增加")
    }

    // MARK: - 写入多字节文本（中文）

    func testWriteText_MultibyteContent_PersistsCorrectly()
    {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("ClipMindTestPasteboard"))
        pasteboard.clearContents()
        let writer = ClipboardWriter(pasteboard: pasteboard)

        let multibyte = "你好世界🌍 import SwiftUI"
        _ = writer.write(text: multibyte)

        XCTAssertEqual(pasteboard.string(forType: .string), multibyte, "多字节文本应完整写入")
    }
}
