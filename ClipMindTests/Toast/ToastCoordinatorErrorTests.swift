import XCTest

@testable import ClipMind

/// F2.1.1 7 个错误场景降级单元测试（设计文档 §8.4）。
///
/// 本测试聚焦错误场景的独立验证，与 ToastCoordinatorTests 中的状态转换测试互补。
/// 共享 Mock 类型（NoScreen/FailOnShow/AnimFailure）定义在 ToastCoordinatorFixtures。
final class ToastCoordinatorErrorTests: XCTestCase
{
    private var windowManager: TestToastWindowManager!
    private var timerSource: VirtualTimerSource!
    private var coordinator: ToastCoordinator!

    override func setUp()
    {
        super.setUp()
        windowManager = TestToastWindowManager()
        timerSource = VirtualTimerSource()
        coordinator = ToastCoordinator(
            windowManager: windowManager,
            timerSource: timerSource,
            isEnabledProvider: { true }
        )
    }

    override func tearDown()
    {
        coordinator?.stop()
        coordinator = nil
        windowManager = nil
        timerSource = nil
        super.tearDown()
    }

    // MARK: - E1 通知载荷缺失文件名

    func testE1MissingFileNameLogsErrorAndDoesNotTrigger()
    {
        let notification = ToastCoordinatorFixtures.makeSavedNotification(
            fileName: nil,
            skipped: false
        )
        coordinator.handleSavedNotification(notification)

        XCTAssertEqual(coordinator.currentState, .hidden, "E1: 文件名缺失应保持隐藏")
        XCTAssertNil(windowManager.lastShownFileName, "E1: 不应触发窗口显示")
    }

    // MARK: - E2 通知载荷事件标识缺失（降级仍触发）

    func testE2MissingEventIdStillTriggersToast()
    {
        let notification = ToastCoordinatorFixtures.makeSavedNotification(
            eventId: "",
            fileName: "test.md"
        )
        coordinator.handleSavedNotification(notification)

        XCTAssertEqual(coordinator.currentState, .appearing, "E2: eventId 缺失应降级仍触发 Toast")
        XCTAssertEqual(windowManager.lastShownFileName, "test.md")
    }

    // MARK: - E3 F2.1 总开关查询失败（保守不显示）

    func testE3IsEnabledProviderThrowsDoesNotTrigger()
    {
        struct ToastTestError: Error {}
        let throwingProvider: () throws -> Bool = {
            throw ToastTestError()
        }
        let coordinator = ToastCoordinator(
            windowManager: windowManager,
            timerSource: timerSource,
            isEnabledProvider: throwingProvider
        )
        let notification = ToastCoordinatorFixtures.makeSavedNotification(fileName: "test.md")
        coordinator.handleSavedNotification(notification)

        XCTAssertEqual(coordinator.currentState, .hidden, "E3: 查询失败应保守不显示")
        XCTAssertNil(windowManager.lastShownFileName)
    }

    // MARK: - E4 屏幕信息查询失败

    func testE4ScreenQueryFailureFallsBackToHidden()
    {
        let noScreenManager = NoScreenToastWindowManager()
        let coordinator = ToastCoordinator(
            windowManager: noScreenManager,
            timerSource: timerSource,
            isEnabledProvider: { true }
        )
        let notification = ToastCoordinatorFixtures.makeSavedNotification(fileName: "test.md")
        coordinator.handleSavedNotification(notification)

        XCTAssertEqual(coordinator.currentState, .hidden, "E4: 屏幕查询失败应回到隐藏")
        XCTAssertNil(coordinator.currentFileName)
    }

    // MARK: - E5 窗口创建失败（与 E4 同路径，验证命名独立的 Mock）

    func testE5WindowCreationFailureFallsBackToHidden()
    {
        let failManager = FailOnShowToastWindowManager()
        let coordinator = ToastCoordinator(
            windowManager: failManager,
            timerSource: timerSource,
            isEnabledProvider: { true }
        )
        let notification = ToastCoordinatorFixtures.makeSavedNotification(fileName: "test.md")
        coordinator.handleSavedNotification(notification)

        XCTAssertEqual(coordinator.currentState, .hidden, "E5: 窗口创建失败应回到隐藏")
        XCTAssertNil(coordinator.currentFileName)
    }

    // MARK: - E6 动画异常跳到目标状态

    func testE6AnimationFailureSkipsToDisplayed()
    {
        let animFailManager = AnimFailureToastWindowManager()
        let coordinator = ToastCoordinator(
            windowManager: animFailManager,
            timerSource: timerSource,
            isEnabledProvider: { true }
        )
        let notification = ToastCoordinatorFixtures.makeSavedNotification(fileName: "test.md")
        coordinator.handleSavedNotification(notification)
        XCTAssertEqual(coordinator.currentState, .appearing)

        // 模拟 completionHandler 兜底强制触发 onDidAppear
        animFailManager.simulateDidAppear()

        XCTAssertEqual(coordinator.currentState, .displayed, "E6: 动画异常后兜底应跳到已显示")
    }

    // MARK: - E7 计时器异常（stop 后状态已清理）

    func testE7TimerFiresAfterStopDoesNotChangeState()
    {
        let notification = ToastCoordinatorFixtures.makeSavedNotification(fileName: "a.md")
        coordinator.handleSavedNotification(notification)
        windowManager.simulateDidAppear()
        XCTAssertEqual(coordinator.currentState, .displayed)

        coordinator.stop()
        XCTAssertEqual(coordinator.currentState, .hidden, "E7: stop 后状态应清理为 hidden")

        // 推进计时器（已取消，不应触发；状态保持 hidden）
        timerSource.advance(by: 2.0)
        XCTAssertEqual(coordinator.currentState, .hidden, "E7: stop 后计时器不应改变状态")
    }

    // MARK: - E7 补充：替换模式下旧计时器句柄替换，旧句柄 cancel 后不触发

    func testE7OldTimerHandleCancelDoesNotFire()
    {
        let first = ToastCoordinatorFixtures.makeSavedNotification(fileName: "a.md")
        coordinator.handleSavedNotification(first)
        windowManager.simulateDidAppear()

        // 推进 1 秒（旧计时器剩余 1 秒）
        timerSource.advance(by: 1.0)

        // 触发替换：旧计时器应被 cancel
        let second = ToastCoordinatorFixtures.makeSavedNotification(fileName: "b.md")
        coordinator.handleSavedNotification(second)
        windowManager.simulateDidCloseImmediately()
        windowManager.simulateDidAppear()

        // 推进 1 秒：旧计时器若未 cancel 会在此触发消失（bug）
        timerSource.advance(by: 1.0)
        XCTAssertEqual(coordinator.currentState, .displayed, "E7: 旧计时器 cancel 后不应触发")

        // 推进剩余 1 秒：新计时器到期，应触发消失
        timerSource.advance(by: 1.0)
        XCTAssertEqual(coordinator.currentState, .disappearing, "E7: 新计时器到期应触发消失")
    }
}
