import Foundation

/// F2.1.1 Toast 协调模块状态机（D2 决策）。
public enum ToastState: Equatable
{
    /// 隐藏：无 Toast 显示，无窗口资源，无计时器
    case hidden
    /// 出现中：窗口承载模块正在执行进入动画
    case appearing
    /// 已显示：进入动画完成，2 秒计时进行中
    case displayed
    /// 替换中：收到新通知，旧 Toast 立即关闭，新 Toast 即将进入（Phase 1 实现）
    case replacing
    /// 消失中：窗口承载模块正在执行退出动画
    case disappearing
}

/// F2.1.1 Toast 协调模块（设计文档 §3.1、§5.1、D2、D3、D4、D6）。
///
/// 职责：
/// - 订阅 AutoSaveService.savedNotification（D3 中心化通知订阅）
/// - 校验跳过标记非真（FR-009）与 F2.1 总开关启用（FR-008，D4 依赖注入闭包）
/// - 驱动 5 状态机（D2，Phase 0 实现 4 状态，Phase 1 实现 replacing）
/// - 管理 2 秒计时（FR-004，D7 注入计时器源）
/// - 主线程派发（D6）
/// - 通过 LogCategory.toast 输出关键状态变更日志（NFR-005）
///
/// 不负责：窗口创建与动画、视图渲染、F2.1 配置管理、F2.1 错误弹窗
public final class ToastCoordinator
{
    /// 2 秒显示时长（FR-004）
    private static let displayDuration: TimeInterval = 2.0

    private let windowManager: ToastWindowManager
    private let timerSource: TimerSource
    private let isEnabledProvider: () throws -> Bool
    private let logger = LogCategory.toast.logger

    /// 当前状态（公开只读，用于测试断言）
    public private(set) var currentState: ToastState = .hidden

    /// 当前计时器句柄（D2：保证同时只有一个有效计时器，R-03 缓解）
    private var currentTimerHandle: TimerHandle?

    /// 当前显示的文件名（用于替换日志与测试）
    private(set) var currentFileName: String?

    /// 替换模式暂存的待显示文件名（Phase 1 任务 8 使用）
    private var pendingFileName: String?

    private var observer: NSObjectProtocol?

    public init(
        windowManager: ToastWindowManager,
        timerSource: TimerSource,
        isEnabledProvider: @escaping () throws -> Bool
    )
    {
        self.windowManager = windowManager
        self.timerSource = timerSource
        self.isEnabledProvider = isEnabledProvider
        setupWindowManagerCallbacks()
        startObservingSavedNotification()
    }

    deinit
    {
        stop()
    }

    /// 停止协调模块，取消所有计时器与通知订阅（用于 App 退出与测试 tearDown）。
    public func stop()
    {
        currentTimerHandle?.cancel()
        currentTimerHandle = nil
        if let observer = observer
        {
            NotificationCenter.default.removeObserver(observer)
            self.observer = nil
        }
    }

    // MARK: - 通知订阅（D3）

    private func startObservingSavedNotification()
    {
        observer = NotificationCenter.default.addObserver(
            forName: AutoSaveService.savedNotification,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            self?.handleSavedNotification(notification)
        }
    }

    // MARK: - 通知处理（D6 主线程派发）

    /// 处理保存完成通知。
    /// 通知可能在 F2.1 串行队列派发，必须切换到主线程处理。
    public func handleSavedNotification(_ notification: Notification)
    {
        // D6：通知回调立即派发到主线程
        if Thread.isMainThread
        {
            handleOnMainThread(notification)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.handleOnMainThread(notification)
            }
        }
    }

    private func handleOnMainThread(_ notification: Notification)
    {
        let userInfo = notification.userInfo ?? [:]
        let eventId = userInfo["eventId"] as? String
        let fileName = userInfo["fileName"] as? String
        let skipped = userInfo["skipped"] as? Bool ?? false

        // FR-009：跳过标记为真不触发
        guard !skipped else
        {
            logger.info("Toast skip: skipped=true eventId=\(eventId ?? "nil", privacy: .public)")
            return
        }

        // FR-008 + E3：F2.1 总开关查询（D4 注入闭包），捕获异常保守不显示
        let isEnabled: Bool
        do
        {
            isEnabled = try isEnabledProvider()
        } catch {
            logger.error("Toast skip: isEnabledProvider threw eventId=\(eventId ?? "nil", privacy: .public)")
            return
        }
        guard isEnabled else
        {
            logger.info("Toast skip: F2.1 disabled eventId=\(eventId ?? "nil", privacy: .public)")
            return
        }

        // E1：必须有文件名（成功路径必有，理论防御）
        guard let fileName = fileName else
        {
            logger.error("Toast skip: fileName missing eventId=\(eventId ?? "nil", privacy: .public)")
            return
        }

        logger.info("Toast trigger: fileName=\(fileName, privacy: .public)")
        logger.info("Toast trigger eventId=\(eventId ?? "nil", privacy: .public)")
        triggerToast(fileName: fileName)
    }

    // MARK: - 状态机驱动（D2）

    private func triggerToast(fileName: String)
    {
        switch currentState
        {
        case .hidden:
            startAppearing(fileName: fileName)
        case .appearing, .displayed, .disappearing, .replacing:
            startReplacing(fileName: fileName)
        }
    }

    /// 启动替换流程：取消旧计时器 → 立即关闭旧窗口 → 等待关闭完成 → 触发新 Toast 进入。
    private func startReplacing(fileName: String)
    {
        currentState = .replacing
        pendingFileName = fileName
        let oldFileName = currentFileName
        logger.info("Toast replace: old=\(oldFileName ?? "nil", privacy: .public)")
        logger.info("Toast replace: new=\(fileName, privacy: .public)")

        // R-03：取消旧计时器，保证同时只有一个有效计时器
        currentTimerHandle?.cancel()
        currentTimerHandle = nil

        // D2 + R-02：立即关闭旧窗口（无退出动画），等待 onDidCloseImmediately 回调后触发新进入
        windowManager.closeImmediately()
    }

    private func startAppearing(fileName: String)
    {
        currentState = .appearing
        currentFileName = fileName
        windowManager.show(fileName: fileName)
    }

    // MARK: - 窗口承载模块回调（D2 状态转换触发器）

    private func setupWindowManagerCallbacks()
    {
        windowManager.onDidAppear = { [weak self] in
            self?.handleDidAppear()
        }
        windowManager.onDidHide = { [weak self] in
            self?.handleDidHide()
        }
        windowManager.onDidCloseImmediately = { [weak self] in
            self?.handleDidCloseImmediately()
        }
    }

    private func handleDidAppear()
    {
        guard currentState == .appearing else { return }
        currentState = .displayed

        // 启动 2 秒计时（D7 注入计时器源）
        currentTimerHandle?.cancel()
        currentTimerHandle = timerSource.schedule(duration: Self.displayDuration) { [weak self] in
            self?.handleTimerFired()
        }
    }

    private func handleTimerFired()
    {
        guard currentState == .displayed else { return }
        currentState = .disappearing
        currentTimerHandle = nil
        windowManager.hide(completion: nil)
    }

    private func handleDidHide()
    {
        currentState = .hidden
        currentFileName = nil
    }

    private func handleDidCloseImmediately()
    {
        // 替换模式专用：旧窗口立即关闭完成后，触发新 Toast 进入
        guard currentState == .replacing else { return }
        guard let newFileName = pendingFileName else
        {
            // 防御：无待显示文件名，回到隐藏
            currentState = .hidden
            currentFileName = nil
            return
        }
        pendingFileName = nil
        startAppearing(fileName: newFileName)
    }
}
