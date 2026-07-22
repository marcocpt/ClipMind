import Foundation

/// 自我写入抑制器（D4 markSelfWrite + checkAndReset，5s 超时）。
///
/// 当 F2.1 替换剪贴板为文件路径后，调用 `markSelfWrite(changeCount:)` 标记。
/// 下一次 PasteboardWatcher 回调时，调用 `checkAndReset(changeCount:)` 检查：
/// 若 changeCount 匹配且未超时（5s），返回 true 表示是自我写入，应跳过 F2.1 处理。
/// 标记为一次性，检查后即清除。
public final class SelfWriteSuppressor
{
    public static let defaultTimeoutInterval: TimeInterval = 5.0

    private let timeoutInterval: TimeInterval
    private let lock = NSLock()
    private var markedChangeCount: Int?
    private var markedAt: Date?

    public init(timeoutInterval: TimeInterval = SelfWriteSuppressor.defaultTimeoutInterval)
    {
        self.timeoutInterval = timeoutInterval
    }

    public func markSelfWrite(changeCount: Int)
    {
        lock.lock()
        defer { lock.unlock() }

        markedChangeCount = changeCount
        markedAt = Date()
        LogCategory.capture.debug("Self-write marked: changeCount=\(changeCount)")
    }

    public func checkAndReset(changeCount: Int) -> Bool
    {
        lock.lock()
        defer { lock.unlock() }

        guard let markedCount = markedChangeCount, let markedTime = markedAt else
        {
            return false
        }

        markedChangeCount = nil
        markedAt = nil

        let elapsed = Date().timeIntervalSince(markedTime)
        if elapsed > timeoutInterval
        {
            LogCategory.capture.debug("Self-write mark expired: elapsed=\(elapsed)")
            return false
        }

        return markedCount == changeCount
    }
}
