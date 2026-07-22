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
        XCTAssertFalse(event.bundleId.isEmpty, "bundleId 应非空（来源 App 无法识别时 build 返回 nil，事件内始终非空）")
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
}
