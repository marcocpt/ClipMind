import Foundation

/// F2.1.1 计时器源协议（D7 可测试性决策）。
///
/// 协调模块通过此协议启动 2 秒计时与取消计时，生产使用 MainTimerSource，
/// 单元测试使用 VirtualTimerSource 手动推进时间，避免真实 2 秒等待。
public protocol TimerSource: AnyObject
{
    /// 启动一次性计时器，duration 秒后回调 callback。
    /// 返回句柄用于取消，取消后回调不再触发。
    func schedule(duration: TimeInterval, callback: @escaping () -> Void) -> TimerHandle
}

/// 计时器句柄，可取消已启动的计时器。
public protocol TimerHandle: AnyObject
{
    func cancel()
}

/// 生产环境计时器源，使用主线程 DispatchSourceTimer（D6）。
public final class MainTimerSource: TimerSource
{
    public init() {}

    public func schedule(duration: TimeInterval, callback: @escaping () -> Void) -> TimerHandle
    {
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + duration)
        timer.setEventHandler(handler: callback)
        timer.resume()
        return MainTimerHandle(timer: timer)
    }
}

private final class MainTimerHandle: TimerHandle
{
    private let timer: DispatchSourceTimer
    private var canceled = false

    init(timer: DispatchSourceTimer)
    {
        self.timer = timer
    }

    func cancel()
    {
        guard !canceled else { return }
        canceled = true
        timer.cancel()
    }
}

/// 测试用虚拟计时器源，不依赖真实时间（D7）。
///
/// 通过 advance(by:) 手动推进虚拟时间，触发到期回调。
/// 用于单元测试加速 2 秒计时与 0.2 秒动画时长验证。
public final class VirtualTimerSource: TimerSource
{
    private struct PendingTimer
    {
        let fireTime: TimeInterval
        let callback: () -> Void
        let id: UUID
        var canceled: Bool
    }

    private var pending: [PendingTimer] = []
    private var currentTime: TimeInterval = 0

    public init() {}

    public func schedule(duration: TimeInterval, callback: @escaping () -> Void) -> TimerHandle
    {
        let id = UUID()
        let timer = PendingTimer(
            fireTime: currentTime + duration,
            callback: callback,
            id: id,
            canceled: false
        )
        pending.append(timer)
        return VirtualTimerHandle(source: self, id: id)
    }

    /// 推进虚拟时间，触发到期回调（按时间顺序触发）。
    public func advance(by delta: TimeInterval)
    {
        currentTime += delta
        let due = pending.filter { $0.fireTime <= currentTime && !$0.canceled }
        let sortedDue = due.sorted { $0.fireTime < $1.fireTime }
        for timer in sortedDue
        {
            timer.callback()
            if let index = pending.firstIndex(where: { $0.id == timer.id })
            {
                pending.remove(at: index)
            }
        }
    }

    /// 当前虚拟时间（测试断言用）。
    public var now: TimeInterval
    {
        currentTime
    }

    fileprivate func cancel(id: UUID)
    {
        if let index = pending.firstIndex(where: { $0.id == id })
        {
            pending[index].canceled = true
        }
    }
}

private final class VirtualTimerHandle: TimerHandle
{
    weak var source: VirtualTimerSource?
    let id: UUID

    init(source: VirtualTimerSource, id: UUID)
    {
        self.source = source
        self.id = id
    }

    func cancel()
    {
        source?.cancel(id: id)
    }
}
