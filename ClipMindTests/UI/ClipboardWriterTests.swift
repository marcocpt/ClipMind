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

    // MARK: - F1.11 Bug 3：写入后调用 markSelfWrite（避免列表重复入库）

    /// 验证 `ClipboardWriter` 写入成功后会调用 `suppressor.markSelfWrite(changeCount:)`，
    /// 使共享抑制器的 `checkAndReset(changeCount:)` 命中，告知 `PasteboardWatcher` 跳过本次捕获。
    ///
    /// 根因：F1.9 粘贴路径的 `PasteCoordinator` → `ClipboardWriter` 写入剪贴板后未通知
    /// `SelfWriteSuppressor`，导致 `PasteboardWatcher` 把"应用自己写入"误识别为"用户外部新复制"，
    /// 把已存在的 clip 当作新内容入库，列表出现重复条目。
    func testWriteText_MarksSelfWrite_WhenSuppressorProvided()
    {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("ClipMindSelfWriteTestPasteboard"))
        pasteboard.clearContents()
        let suppressor = SelfWriteSuppressor()
        let writer = ClipboardWriter(pasteboard: pasteboard, suppressor: suppressor)

        let success = writer.write(text: "duplicate-test-content")
        XCTAssertTrue(success, "写入应成功")

        let currentChangeCount = pasteboard.changeCount
        XCTAssertTrue(
            suppressor.checkAndReset(changeCount: currentChangeCount),
            "ClipboardWriter 写入成功后应调用 markSelfWrite，使 PasteboardWatcher 能识别为自我写入并跳过捕获"
        )
    }

    /// 验证未注入 suppressor 时（向后兼容）写入流程正常，不崩溃、不影响返回值。
    func testWriteText_WithoutSuppressor_StillSucceeds()
    {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("ClipMindNoSuppressorTestPasteboard"))
        pasteboard.clearContents()
        let writer = ClipboardWriter(pasteboard: pasteboard)

        let success = writer.write(text: "no-suppressor")

        XCTAssertTrue(success, "未注入 suppressor 时写入仍应成功")
        XCTAssertEqual(pasteboard.string(forType: .string), "no-suppressor")
    }

    /// 端到端验证：`ClipboardWriter` 与 `PasteboardWatcher` 共享同一个 `SelfWriteSuppressor` 时，
    /// 应用自己写入剪贴板不会触发 `PasteboardWatcher.onPasteboardChange` 回调（不会重复入库）。
    ///
    /// 测试模式与 `PasteboardWatcherEventTests.testSelfWriteEventSuppressed` 一致：
    /// 先构造 watcher（捕获 lastChangeCount 基线），再写入内容并触发 handlePasteboardChange。
    func testWriteText_WithSharedSuppressor_PasteboardWatcherSkipsCapture()
    {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("ClipMindIntegrationTestPasteboard"))
        pasteboard.clearContents()
        let suppressor = SelfWriteSuppressor()

        // 先构造 watcher（捕获当前 changeCount 作为基线），再写入外部内容
        let watcher = PasteboardWatcher(
            pasteboard: pasteboard,
            contentReader: ContentReader(),
            deduplicator: Deduplicator(),
            suppressor: suppressor
        )

        var captureCallCount = 0
        watcher.onPasteboardChange = { _ in
            captureCallCount += 1
        }

        // 基线：模拟"上一次外部复制"（内容与即将写入的不同，避免 Deduplicator 误命中
        // 掩盖 suppressor 缺失的 bug）
        pasteboard.clearContents()
        pasteboard.setString("previous-external-content", forType: .string)
        watcher.handlePasteboardChange()
        XCTAssertEqual(captureCallCount, 1, "基线：首次外部复制应被捕获")

        // 应用自己写入剪贴板（模拟 PasteCoordinator.handlePaste 触发的写入）
        let writer = ClipboardWriter(pasteboard: pasteboard, suppressor: suppressor)
        XCTAssertTrue(writer.write(text: "self-written-content"), "应用自身写入应成功")

        // 触发 watcher 轮询回调（生产环境由 Timer 调度，测试直接同步调用）
        watcher.handlePasteboardChange()

        XCTAssertEqual(
            captureCallCount,
            1,
            "共享 suppressor 命中后，PasteboardWatcher 应跳过本次捕获，捕获次数不应增加"
        )
    }
}
