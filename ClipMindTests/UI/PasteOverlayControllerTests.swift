import AppKit
@testable import ClipMind
import XCTest

final class PasteOverlayControllerTests: XCTestCase
{
    // MARK: - TC-F1.9-7-01 显示浮层时文案为"已复制，按 Cmd+V 粘贴"

    @MainActor
    func testShowOverlay_DisplaysGenericMessage_WithoutClipboardContent()
    {
        let controller = makeController()

        controller.showOverlay()

        XCTAssertTrue(controller.isOverlayVisible, "浮层应已显示")
        XCTAssertEqual(controller.overlayTextForTesting, "已复制，按 Cmd+V 粘贴", "浮层应显示通用文案")

        controller.hideOverlay()
    }

    // MARK: - TC-F1.9-SEC-02 浮层不显示剪贴板原文

    @MainActor
    func testShowOverlay_MessageDoesNotContainClipboardContent()
    {
        let controller = makeController()

        controller.showOverlay()

        let message = controller.overlayTextForTesting
        XCTAssertFalse(message.contains("敏感内容"), "浮层文案不应包含剪贴板原文")
        XCTAssertFalse(message.contains("密码"), "浮层文案不应包含剪贴板原文")
        XCTAssertEqual(message, "已复制，按 Cmd+V 粘贴", "浮层仅显示通用文案")

        controller.hideOverlay()
    }

    // MARK: - TC-F1.9-7-02 剪贴板被消费后浮层消失

    @MainActor
    func testHideOverlay_OnConsumption_Disappears()
    {
        let watcher = MockConsumerWatcher()
        let controller = makeController(consumerWatcher: watcher)

        controller.showOverlay()
        XCTAssertTrue(controller.isOverlayVisible)

        // 模拟剪贴板被消费
        watcher.simulateConsumed()

        XCTAssertFalse(controller.isOverlayVisible, "消费后浮层应消失")
    }

    // MARK: - TC-F1.9-7-03 超时兜底后浮层消失

    @MainActor
    func testHideOverlay_OnTimeout_Disappears()
    {
        let timer = MockOverlayTimer()
        let controller = makeController(timerScheduler: timer)

        controller.showOverlay()
        XCTAssertTrue(controller.isOverlayVisible)

        // 模拟超时触发
        timer.simulateTimeout()

        XCTAssertFalse(controller.isOverlayVisible, "超时后浮层应消失")
    }

    // MARK: - 消费与超时互斥（先触发者生效，另一路径被取消）

    @MainActor
    func testHideOverlay_ConsumptionFirst_CancelsTimeout()
    {
        let watcher = MockConsumerWatcher()
        let timer = MockOverlayTimer()
        let controller = makeController(consumerWatcher: watcher, timerScheduler: timer)

        controller.showOverlay()
        XCTAssertTrue(timer.isTimeoutScheduled, "显示浮层时应调度超时")

        watcher.simulateConsumed()
        XCTAssertFalse(controller.isOverlayVisible)

        // 消费后超时不应再触发关闭（已关闭）
        timer.simulateTimeout()
        XCTAssertFalse(controller.isOverlayVisible, "消费后超时不应重复关闭")
    }

    @MainActor
    func testHideOverlay_TimeoutFirst_CancelsConsumption()
    {
        let watcher = MockConsumerWatcher()
        let timer = MockOverlayTimer()
        let controller = makeController(consumerWatcher: watcher, timerScheduler: timer)

        controller.showOverlay()

        timer.simulateTimeout()
        XCTAssertFalse(controller.isOverlayVisible)
        XCTAssertFalse(watcher.isWatching, "超时后应停止消费监听")
    }

    // MARK: - 超时时长从 QuickPasteSettings 读取

    @MainActor
    func testShowOverlay_ReadsTimeoutDurationFromSettings()
    {
        let defaults = UserDefaults(suiteName: "ClipMind.OverlayTests.\(UUID().uuidString)")!
        let settings = QuickPasteSettings(defaults: defaults)
        settings.saveOverlayDuration(10.0)
        let timer = MockOverlayTimer()
        let controller = makeController(timerScheduler: timer, settings: settings)

        controller.showOverlay()

        XCTAssertEqual(timer.scheduledDuration, 10.0, "超时时长应从 QuickPasteSettings 读取")

        controller.hideOverlay()
    }

    // MARK: - 测试辅助

    @MainActor
    private func makeController(
        consumerWatcher: ClipboardConsumerWatcherProtocol = MockConsumerWatcher(),
        timerScheduler: OverlayTimerScheduling = MockOverlayTimer(),
        settings: QuickPasteSettings = QuickPasteSettings(
            defaults: UserDefaults(suiteName: "ClipMind.OverlayTests.\(UUID().uuidString)")!
        )
    ) -> PasteOverlayController
    {
        PasteOverlayController(
            consumerWatcher: consumerWatcher,
            timerScheduler: timerScheduler,
            settings: settings,
            screenLocator: ScreenCenterOverlayLocator()
        )
    }

    /// 屏幕中央浮层定位器。
    private final class ScreenCenterOverlayLocator: OverlayScreenLocating
    {
        func locatePosition() -> NSPoint
        {
            let screenFrame = NSScreen.main?.frame ?? .zero
            return NSPoint(x: screenFrame.midX - 100, y: screenFrame.midY - 30)
        }
    }

    /// Mock 消费监听器。
    private final class MockConsumerWatcher: ClipboardConsumerWatcherProtocol
    {
        private var onConsumed: (() -> Void)?
        private(set) var isWatching = false

        func start(onConsumed: @escaping () -> Void)
        {
            self.onConsumed = onConsumed
            isWatching = true
        }

        func stop()
        {
            isWatching = false
            onConsumed = nil
        }

        func simulateConsumed()
        {
            onConsumed?()
            isWatching = false
            onConsumed = nil
        }
    }

    /// Mock 超时计时器。
    private final class MockOverlayTimer: OverlayTimerScheduling
    {
        private var timeoutHandler: (() -> Void)?
        private(set) var isTimeoutScheduled = false
        private(set) var scheduledDuration: TimeInterval = 0

        func scheduleTimeout(after duration: TimeInterval, handler: @escaping () -> Void)
        {
            scheduledDuration = duration
            timeoutHandler = handler
            isTimeoutScheduled = true
        }

        func cancelTimeout()
        {
            isTimeoutScheduled = false
            timeoutHandler = nil
        }

        func simulateTimeout()
        {
            let handler = timeoutHandler
            cancelTimeout()
            handler?()
        }
    }
}
