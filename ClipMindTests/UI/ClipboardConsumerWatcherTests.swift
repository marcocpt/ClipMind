@testable import ClipMind
import Foundation
import XCTest

final class ClipboardConsumerWatcherTests: XCTestCase
{
    // MARK: - 启动监听记录基准 changeCount

    func testStart_CapturesBaselineChangeCount()
    {
        let provider = MockChangeCountProvider(changeCount: 10)
        let watcher = ClipboardConsumerWatcher(changeCountProvider: provider)

        watcher.start { }

        XCTAssertEqual(watcher.baselineChangeCountForTesting, 10, "启动时应记录基准 changeCount")
        watcher.stop()
    }

    // MARK: - changeCount 未变化时不触发回调

    func testPoll_NoChange_DoesNotTriggerCallback()
    {
        let provider = MockChangeCountProvider(changeCount: 10)
        var consumed = false
        let watcher = ClipboardConsumerWatcher(changeCountProvider: provider, pollInterval: 0.05)

        watcher.start { consumed = true }

        // 等待两个轮询周期，changeCount 未变化
        let waitExpectation = expectation(description: "wait for poll cycles")
        waitExpectation.isInverted = true
        wait(for: [waitExpectation], timeout: 0.3)

        XCTAssertFalse(consumed, "changeCount 未变化时不应触发消费回调")
        watcher.stop()
    }

    // MARK: - changeCount 再次变化时触发回调

    func testPoll_ChangeCountIncreased_TriggersCallback()
    {
        let provider = MockChangeCountProvider(changeCount: 10)
        let consumedExpectation = expectation(description: "consumed callback triggered")
        let watcher = ClipboardConsumerWatcher(changeCountProvider: provider, pollInterval: 0.05)

        watcher.start { consumedExpectation.fulfill() }

        // 模拟用户在其他应用按 Cmd+V 后剪贴板 changeCount 变化
        provider.changeCount = 11

        wait(for: [consumedExpectation], timeout: 1.0)
    }

    // MARK: - stop 后不再触发回调

    func testStop_PreventsFurtherCallbacks()
    {
        let provider = MockChangeCountProvider(changeCount: 10)
        var consumed = false
        let watcher = ClipboardConsumerWatcher(changeCountProvider: provider, pollInterval: 0.05)

        watcher.start { consumed = true }
        watcher.stop()

        provider.changeCount = 11

        let waitExpectation = expectation(description: "wait after stop")
        waitExpectation.isInverted = true
        wait(for: [waitExpectation], timeout: 0.3)

        XCTAssertFalse(consumed, "stop 后不应再触发回调")
    }

    // MARK: - 测试辅助

    private final class MockChangeCountProvider: ClipboardChangeCountProviding
    {
        var changeCount: Int

        init(changeCount: Int)
        {
            self.changeCount = changeCount
        }

        func currentChangeCount() -> Int
        {
            changeCount
        }
    }
}
