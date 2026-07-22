import Foundation

/// 轮询工具（D17：10ms 间隔，3s 超时，禁止 sleep 3）。
///
/// 替代固定 sleep 等待异步逻辑完成。使用 `Thread.sleep(forTimeInterval:)` 进行短间隔轮询，
/// 累计等待时间不超过 timeout。禁止使用 `sleep(3)` 等长固定延迟。
public enum PollingHelper
{
    public static let defaultInterval: TimeInterval = 0.01
    public static let defaultTimeout: TimeInterval = 3.0

    @discardableResult
    public static func waitUntil(
        interval: TimeInterval = defaultInterval,
        timeout: TimeInterval = defaultTimeout,
        condition: () -> Bool
    ) -> Bool
    {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline
        {
            if condition()
            {
                return true
            }
            Thread.sleep(forTimeInterval: interval)
        }

        return condition()
    }
}
