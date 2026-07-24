import AppKit
import Foundation

/// 剪贴板变化计数提供协议（依赖注入，便于测试 mock）。
///
/// 生产实现返回 `NSPasteboard.general.changeCount`；测试 mock 返回可控值。
protocol ClipboardChangeCountProviding: AnyObject
{
    /// 返回当前剪贴板变化计数。
    func currentChangeCount() -> Int
}

/// 系统剪贴板变化计数提供器（默认实现）。
final class SystemChangeCountProvider: ClipboardChangeCountProviding
{
    func currentChangeCount() -> Int
    {
        NSPasteboard.general.changeCount
    }
}

/// 剪贴板消费监听器。
///
/// 设计文档第 3.8 节 + 第 7.6 节。
/// 通过轮询剪贴板变化计数判定消费：写入时记录基准计数，
/// 当计数再次变化时（用户按 Cmd+V 后部分应用会重新写入剪贴板）视为被消费。
///
/// 不比对剪贴板内容（NFR-003 安全性，不读取剪贴板原文）。
/// 使用 DispatchSourceTimer 轮询，不使用 sleep（CODING_STANDARDS 禁止用 sleep 等待异步）。
final class ClipboardConsumerWatcher
{
    private let changeCountProvider: ClipboardChangeCountProviding
    private let pollInterval: TimeInterval
    private var timer: DispatchSourceTimer?
    private var baseline: Int = 0

    /// 消费回调（changeCount 再次变化时触发）。
    private var onConsumed: (() -> Void)?

    /// - Parameters:
    ///   - changeCountProvider: 剪贴板变化计数提供器
    ///   - pollInterval: 轮询间隔（秒），默认 0.2 秒
    init(
        changeCountProvider: ClipboardChangeCountProviding = SystemChangeCountProvider(),
        pollInterval: TimeInterval = 0.2
    )
    {
        self.changeCountProvider = changeCountProvider
        self.pollInterval = pollInterval
    }

    deinit
    {
        stop()
    }

    /// 启动消费监听。
    /// - Parameter onConsumed: 剪贴板被消费时的回调
    func start(onConsumed: @escaping () -> Void)
    {
        stop()
        baseline = changeCountProvider.currentChangeCount()
        self.onConsumed = onConsumed

        let timer = DispatchSource.makeTimerSource(queue: .main)
        let intervalMs = Int(pollInterval * 1000)
        let repeatingInterval: DispatchTimeInterval = .milliseconds(intervalMs)
        timer.schedule(deadline: .now() + pollInterval, repeating: repeatingInterval)
        timer.setEventHandler { [weak self] in
            self?.checkChangeCount()
        }
        timer.resume()
        self.timer = timer
        LogCategory.ui.info("Clipboard consumer watcher started, baseline: \(baseline)")
    }

    /// 停止消费监听。
    func stop()
    {
        timer?.cancel()
        timer = nil
        onConsumed = nil
    }

    // MARK: - 测试辅助

    /// 仅供单元测试读取基准 changeCount。
    var baselineChangeCountForTesting: Int
    {
        baseline
    }

    // MARK: - 私有

    private func checkChangeCount()
    {
        let current = changeCountProvider.currentChangeCount()
        guard current != baseline else { return }

        LogCategory.ui.info("Clipboard consumed, changeCount: \(baseline) -> \(current)")
        let callback = onConsumed
        stop()
        callback?()
    }
}
