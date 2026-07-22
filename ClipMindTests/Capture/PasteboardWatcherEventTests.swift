import AppKit
import XCTest

@testable import ClipMind

final class PasteboardWatcherEventTests: XCTestCase
{
    private var pasteboard: NSPasteboard!
    private var watcher: PasteboardWatcher!
    private var eventBuilder: CaptureEventBuilder!
    private var defaults: UserDefaults!

    override func setUpWithError() throws
    {
        pasteboard = NSPasteboard(name: .init("test-pw-\(UUID().uuidString)"))
        pasteboard.clearContents()

        defaults = UserDefaults(suiteName: "test-pw-\(UUID().uuidString)")!
        let settingsStore = AutoSaveSettingsStore(defaults: defaults)
        let sensitiveDetector = SensitiveDetector(defaults: defaults)
        let blacklistService = BlacklistService(defaults: defaults)
        let appDetector = AppDetector()
        eventBuilder = CaptureEventBuilder(
            appDetector: appDetector,
            sensitiveDetector: sensitiveDetector,
            blacklistService: blacklistService,
            settingsStore: settingsStore
        )

        watcher = PasteboardWatcher(
            pasteboard: pasteboard,
            eventBuilder: eventBuilder
        )
    }

    override func tearDownWithError() throws
    {
        watcher?.stopWatching()
        if let suite = defaults?.dictionaryRepresentation()
        {
            for key in suite.keys
            {
                defaults?.removeObject(forKey: key)
            }
        }
    }

    // MARK: - TC-UT-50：onPasteboardChange 回调接收 CaptureEvent

    func testCallbackReceivesCaptureEvent() throws
    {
        let expectation = XCTestExpectation(description: "回调应接收 CaptureEvent")
        var receivedEvent: CaptureEvent?

        watcher.onPasteboardChange = { event in
            receivedEvent = event
            expectation.fulfill()
        }

        pasteboard.clearContents()
        pasteboard.setString("hello capture event", forType: .string)
        watcher.handlePasteboardChange()

        wait(for: [expectation], timeout: 2.0)

        let event = try XCTUnwrap(receivedEvent)
        XCTAssertEqual(event.changeCount, pasteboard.changeCount)
        if case .text(let text) = event.content
        {
            XCTAssertEqual(text, "hello capture event")
        } else {
            XCTFail("内容应为 .text 类型")
        }
        XCTAssertFalse(event.bundleId.isEmpty, "bundleId 应非空（来源 App 无法识别时使用回退值，事件内始终非空）")
        XCTAssertFalse(event.appName.isEmpty, "appName 应非空")
    }

    // MARK: - TC-UT-51：去重逻辑保留（重复内容不触发回调）

    func testDedupStillWorks() throws
    {
        var callCount = 0
        watcher.onPasteboardChange = { _ in
            callCount += 1
        }

        pasteboard.clearContents()
        pasteboard.setString("dedup content", forType: .string)
        watcher.handlePasteboardChange()
        XCTAssertEqual(callCount, 1, "首次复制应触发回调")

        // 同一 changeCount 不再触发
        watcher.handlePasteboardChange()
        XCTAssertEqual(callCount, 1, "同一 changeCount 不应重复触发")
    }

    // MARK: - TC-UT-52：eventBuilder 为 nil 时回退最小事件（F1.x 兼容）

    func testNilEventBuilderFallback() throws
    {
        let fallbackWatcher = PasteboardWatcher(pasteboard: pasteboard, eventBuilder: nil)
        let expectation = XCTestExpectation(description: "nil eventBuilder 仍应触发回调")
        var receivedContent: ClipContent?

        fallbackWatcher.onPasteboardChange = { event in
            receivedContent = event.content
            expectation.fulfill()
        }

        pasteboard.clearContents()
        pasteboard.setString("fallback content", forType: .string)
        fallbackWatcher.handlePasteboardChange()

        wait(for: [expectation], timeout: 2.0)

        if case .text(let text) = receivedContent
        {
            XCTAssertEqual(text, "fallback content")
        } else {
            XCTFail("回退事件内容应为 .text")
        }
    }

    // MARK: - TC-UT-53：敏感内容不再被 PasteboardWatcher 过滤（迁移到 B0）

    func testSensitiveContentNotFilteredByWatcher() throws
    {
        let expectation = XCTestExpectation(description: "敏感内容应到达回调")
        var receivedEvent: CaptureEvent?

        watcher.onPasteboardChange = { event in
            receivedEvent = event
            expectation.fulfill()
        }

        pasteboard.clearContents()
        pasteboard.setString("password=secret123", forType: .string)
        watcher.handlePasteboardChange()

        wait(for: [expectation], timeout: 2.0)

        let event = try XCTUnwrap(receivedEvent)
        XCTAssertEqual(event.sensitiveResult.isSensitive, true, "敏感结果应打包进事件")
    }

    // MARK: - TC-UT-72：自我写入事件被抑制（FR-015/D4）

    /// 验证 ClipboardReplacer 写入路径后标记的 changeCount，PasteboardWatcher
    /// 下次轮询时应通过 checkAndReset 命中并跳过完整捕获流程。
    /// 这是 F2.1 自我写入死循环 bug（文件路径被当作新复制内容再次保存）的核心防线。
    func testSelfWriteEventSuppressed() throws
    {
        let suppressor = SelfWriteSuppressor()
        let watcherWithSuppressor = PasteboardWatcher(
            pasteboard: pasteboard,
            eventBuilder: eventBuilder,
            suppressor: suppressor
        )

        var callCount = 0
        watcherWithSuppressor.onPasteboardChange = { _ in
            callCount += 1
        }

        // 首次：正常复制长内容
        pasteboard.clearContents()
        pasteboard.setString("original long content that exceeds threshold", forType: .string)
        watcherWithSuppressor.handlePasteboardChange()
        XCTAssertEqual(callCount, 1, "首次复制应触发回调")

        // 模拟 F2.1 自我写入：替换剪贴板为文件路径并标记
        pasteboard.clearContents()
        pasteboard.setString("/Users/test/Clips/original-long-content.md", forType: .string)
        let newChangeCount = pasteboard.changeCount
        suppressor.markSelfWrite(changeCount: newChangeCount)

        // 第二次：自我写入事件应被抑制，不触发回调
        watcherWithSuppressor.handlePasteboardChange()
        XCTAssertEqual(callCount, 1, "自我写入事件应被抑制，不触发回调")
    }

    // MARK: - TC-UT-73：未标记自我写入时正常事件不被抑制

    func testNonSelfWriteEventNotSuppressed() throws
    {
        let suppressor = SelfWriteSuppressor()
        let watcherWithSuppressor = PasteboardWatcher(
            pasteboard: pasteboard,
            eventBuilder: eventBuilder,
            suppressor: suppressor
        )

        var callCount = 0
        watcherWithSuppressor.onPasteboardChange = { _ in
            callCount += 1
        }

        // 首次复制
        pasteboard.clearContents()
        pasteboard.setString("first content", forType: .string)
        watcherWithSuppressor.handlePasteboardChange()
        XCTAssertEqual(callCount, 1, "首次复制应触发回调")

        // 第二次：不同内容，未标记自我写入，应正常触发
        pasteboard.clearContents()
        pasteboard.setString("second content", forType: .string)
        watcherWithSuppressor.handlePasteboardChange()
        XCTAssertEqual(callCount, 2, "未标记自我写入时正常事件应触发回调")
    }

    // MARK: - TC-UT-74：suppressor 为 nil 时不抑制（F1.x 兼容）

    func testSuppressorNilNoSuppression() throws
    {
        let watcherWithoutSuppressor = PasteboardWatcher(
            pasteboard: pasteboard,
            eventBuilder: eventBuilder
        )

        var callCount = 0
        watcherWithoutSuppressor.onPasteboardChange = { _ in
            callCount += 1
        }

        pasteboard.clearContents()
        pasteboard.setString("content one", forType: .string)
        watcherWithoutSuppressor.handlePasteboardChange()
        XCTAssertEqual(callCount, 1)

        pasteboard.clearContents()
        pasteboard.setString("content two", forType: .string)
        watcherWithoutSuppressor.handlePasteboardChange()
        XCTAssertEqual(callCount, 2, "suppressor 为 nil 时不应抑制")
    }
}
