import AppKit
import XCTest

@testable import ClipMind

final class PasteboardWatcherTests: XCTestCase {
    private var pasteboard: NSPasteboard!
    private var watcher: PasteboardWatcher!

    override func setUpWithError() throws {
        pasteboard = NSPasteboard(name: .init("test-watcher-\(UUID().uuidString)"))
        pasteboard.clearContents()
        watcher = PasteboardWatcher(pasteboard: pasteboard)
    }

    override func tearDownWithError() throws {
        watcher.stopWatching()
        watcher = nil
        pasteboard = nil
    }

    // MARK: - 启动与停止

    func testStartWatching() throws {
        watcher.startWatching(interval: 0.5)
        XCTAssertNotNil(watcher.timer, "启动后 timer 应不为 nil")
    }

    func testStopWatching() throws {
        watcher.startWatching(interval: 0.5)
        watcher.stopWatching()
        XCTAssertNil(watcher.timer, "停止后 timer 应为 nil")
    }

    // MARK: - changeCount 检测

    func testChangeCountDetection() throws {
        let expectation = XCTestExpectation(description: "剪贴板变化应触发回调")

        watcher.onPasteboardChange = { _ in
            expectation.fulfill()
        }

        // 模拟 changeCount 变化：clearContents + setString 会增加 changeCount
        pasteboard.clearContents()
        pasteboard.setString("hello", forType: .string)
        watcher.handlePasteboardChange()

        wait(for: [expectation], timeout: 1.0)
    }

    func testNoChangeNoCallback() throws {
        let expectation = XCTestExpectation(description: "无变化不应触发回调")
        expectation.isInverted = true

        watcher.onPasteboardChange = { _ in
            expectation.fulfill()
        }

        // changeCount 未变化，直接调用不应触发回调
        watcher.handlePasteboardChange()

        wait(for: [expectation], timeout: 0.5)
    }

    // MARK: - 回调内容

    func testOnPasteboardChangeCallback() throws {
        let expectation = XCTestExpectation(description: "回调应传入正确的内容")
        var receivedContent: ClipContent?

        watcher.onPasteboardChange = { content in
            receivedContent = content
            expectation.fulfill()
        }

        pasteboard.clearContents()
        pasteboard.setString("hello world", forType: .string)
        watcher.handlePasteboardChange()

        wait(for: [expectation], timeout: 1.0)

        guard case .text(let value) = receivedContent else {
            XCTFail("应收到 .text 类型的内容")
            return
        }
        XCTAssertEqual(value, "hello world")
    }

    // MARK: - 去重集成

    func testDuplicateContentNotForwarded() throws {
        var callCount = 0
        watcher.onPasteboardChange = { _ in
            callCount += 1
        }

        // 第一次设置内容，应触发回调
        pasteboard.clearContents()
        pasteboard.setString("same", forType: .string)
        watcher.handlePasteboardChange()
        XCTAssertEqual(callCount, 1, "首次内容应触发回调")

        // 再次变化但内容相同，应被去重过滤
        pasteboard.clearContents()
        pasteboard.setString("same", forType: .string)
        watcher.handlePasteboardChange()
        XCTAssertEqual(callCount, 1, "重复内容不应再次触发回调")
    }
}
