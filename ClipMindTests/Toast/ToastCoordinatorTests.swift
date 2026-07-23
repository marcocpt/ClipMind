import XCTest

@testable import ClipMind

final class ToastCoordinatorTests: XCTestCase
{
    private var coordinator: ToastCoordinator!
    private var windowManager: TestToastWindowManager!
    private var timerSource: VirtualTimerSource!
    private var isEnabled: Bool = true

    override func setUp()
    {
        super.setUp()
        windowManager = TestToastWindowManager()
        timerSource = VirtualTimerSource()
        coordinator = ToastCoordinator(
            windowManager: windowManager,
            timerSource: timerSource,
            isEnabledProvider: { [unowned self] in self.isEnabled }
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

    // MARK: - 初始状态

    func testInitialStateIsHidden()
    {
        XCTAssertEqual(coordinator.currentState, .hidden, "初始状态应为隐藏")
    }

    // MARK: - TC-UT-01 隐藏 → 出现中

    func testHiddenToAppearingOnSavedNotification()
    {
        let notification = ToastCoordinatorFixtures.makeSavedNotification(
            eventId: "evt-1",
            fileName: "hello.md",
            skipped: false
        )
        coordinator.handleSavedNotification(notification)

        XCTAssertEqual(coordinator.currentState, .appearing, "收到保存通知应转为出现中")
        XCTAssertEqual(windowManager.lastShownFileName, "hello.md", "应触发窗口显示")
    }

    // MARK: - TC-UT-02 出现中 → 已显示

    func testAppearingToDisplayedOnDidAppear()
    {
        let notification = ToastCoordinatorFixtures.makeSavedNotification(fileName: "a.md")
        coordinator.handleSavedNotification(notification)
        XCTAssertEqual(coordinator.currentState, .appearing)

        // 模拟窗口承载模块回调进入动画完成
        windowManager.simulateDidAppear()

        XCTAssertEqual(coordinator.currentState, .displayed, "进入动画完成应转为已显示")
    }

    // MARK: - TC-UT-05 已显示 → 消失中

    func testDisplayedToDisappearingOnTimerFire()
    {
        let notification = ToastCoordinatorFixtures.makeSavedNotification(fileName: "a.md")
        coordinator.handleSavedNotification(notification)
        windowManager.simulateDidAppear()
        XCTAssertEqual(coordinator.currentState, .displayed)

        // 推进虚拟计时器到 2 秒
        timerSource.advance(by: 2.0)

        XCTAssertEqual(coordinator.currentState, .disappearing, "2 秒计时结束应转为消失中")
        XCTAssertTrue(windowManager.hideCalled, "应触发窗口退出动画")
    }

    // MARK: - TC-UT-06 消失中 → 隐藏

    func testDisappearingToHiddenOnDidHide()
    {
        let notification = ToastCoordinatorFixtures.makeSavedNotification(fileName: "a.md")
        coordinator.handleSavedNotification(notification)
        windowManager.simulateDidAppear()
        timerSource.advance(by: 2.0)
        XCTAssertEqual(coordinator.currentState, .disappearing)

        // 模拟窗口承载模块回调退出动画完成
        windowManager.simulateDidHide()

        XCTAssertEqual(coordinator.currentState, .hidden, "退出动画完成应转为隐藏")
    }

    // MARK: - 跳过标记为真不触发（FR-009）

    func testSkippedNotificationDoesNotTriggerToast()
    {
        let notification = ToastCoordinatorFixtures.makeSavedNotification(
            fileName: nil,
            skipped: true
        )
        coordinator.handleSavedNotification(notification)

        XCTAssertEqual(coordinator.currentState, .hidden, "跳过标记为真应保持隐藏")
        XCTAssertNil(windowManager.lastShownFileName, "不应触发窗口显示")
    }

    // MARK: - F2.1 总开关关闭时不触发（FR-008）

    func testDisabledF2xSwitchDoesNotTriggerToast()
    {
        isEnabled = false
        let notification = ToastCoordinatorFixtures.makeSavedNotification(fileName: "a.md")
        coordinator.handleSavedNotification(notification)

        XCTAssertEqual(coordinator.currentState, .hidden, "总开关关闭应保持隐藏")
        XCTAssertNil(windowManager.lastShownFileName, "不应触发窗口显示")
    }

    // MARK: - 主线程派发（D6）

    func testHandleSavedNotificationDispatchesToMainThread()
    {
        let expectation = XCTestExpectation(description: "main thread dispatched")
        let notification = ToastCoordinatorFixtures.makeSavedNotification(fileName: "a.md")

        // 在后台线程调用 handleSavedNotification
        DispatchQueue.global().async
        {
            self.coordinator.handleSavedNotification(notification)
            DispatchQueue.main.async
            {
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 1.0)
        // 主线程派发后状态应已变更
        XCTAssertEqual(coordinator.currentState, .appearing, "应在主线程派发后转换状态")
    }

    // MARK: - TC-UT-09 启动新 2 秒计时（D2 不变量）

    func testNewTimerStartedOnAppearing()
    {
        let notification = ToastCoordinatorFixtures.makeSavedNotification(fileName: "a.md")
        coordinator.handleSavedNotification(notification)
        windowManager.simulateDidAppear()
        XCTAssertEqual(coordinator.currentState, .displayed)

        // 推进 1 秒，不应触发消失
        timerSource.advance(by: 1.0)
        XCTAssertEqual(coordinator.currentState, .displayed)

        // 再推进 1 秒，应触发消失
        timerSource.advance(by: 1.0)
        XCTAssertEqual(coordinator.currentState, .disappearing)
    }

    // MARK: - E1 通知载荷缺失文件名

    func testE1MissingFileNameDoesNotTriggerToast()
    {
        let notification = ToastCoordinatorFixtures.makeSavedNotification(
            fileName: nil,
            skipped: false
        )
        coordinator.handleSavedNotification(notification)

        XCTAssertEqual(coordinator.currentState, .hidden, "文件名缺失应保持隐藏")
        XCTAssertNil(windowManager.lastShownFileName)
    }

    // MARK: - E2 通知载荷事件标识缺失（降级处理）

    func testE2MissingEventIdStillTriggersToast()
    {
        let notification = ToastCoordinatorFixtures.makeSavedNotification(
            eventId: "",
            fileName: "test.md",
            skipped: false
        )
        coordinator.handleSavedNotification(notification)

        XCTAssertEqual(coordinator.currentState, .appearing, "eventId 缺失应降级处理仍触发 Toast")
    }

    // MARK: - E3 F2.1 总开关查询失败（保守策略，不显示）

    func testE3IsEnabledProviderThrowsDoesNotTriggerToast()
    {
        let throwingProvider: () throws -> Bool = {
            struct ToastTestError: Error {}
            throw ToastTestError()
        }
        let coordinator = ToastCoordinator(
            windowManager: windowManager,
            timerSource: timerSource,
            isEnabledProvider: throwingProvider
        )
        let notification = ToastCoordinatorFixtures.makeSavedNotification(fileName: "test.md")
        coordinator.handleSavedNotification(notification)

        XCTAssertEqual(coordinator.currentState, .hidden, "查询失败应保守不显示")
    }
}

/// 测试专用窗口承载模块，记录调用并支持手动触发回调。
final class TestToastWindowManager: ToastWindowManager
{
    private(set) var lastShownFileName: String?
    private(set) var hideCalled = false
    private(set) var closeImmediatelyCalled = false

    override func show(fileName: String)
    {
        lastShownFileName = fileName
        // 测试不真实创建窗口，仅记录调用
    }

    override func hide(completion: (() -> Void)?)
    {
        hideCalled = true
        // 测试不真实执行动画，由 simulateDidHide 触发回调
    }

    override func closeImmediately()
    {
        closeImmediatelyCalled = true
        // 测试不真实执行关闭，由 simulateDidCloseImmediately 触发回调
    }

    func simulateDidAppear()
    {
        onDidAppear?()
    }

    func simulateDidHide()
    {
        onDidHide?()
    }

    func simulateDidCloseImmediately()
    {
        onDidCloseImmediately?()
    }
}
