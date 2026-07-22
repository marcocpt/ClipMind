import AppKit
import Foundation

/// 剪贴板替换器（D5 changeCount 前置条件 + D4 markSelfWrite）。
public final class ClipboardReplacer
{
    private let pasteboard: NSPasteboard
    private let suppressor: SelfWriteSuppressor
    private let logger = LogCategory.capture.logger

    public init(pasteboard: NSPasteboard, suppressor: SelfWriteSuppressor)
    {
        self.pasteboard = pasteboard
        self.suppressor = suppressor
    }

    /// 替换剪贴板内容（D5 changeCount 前置条件 + D4 markSelfWrite）。
    @discardableResult
    public func replace(with newPath: String, expectedChangeCount: Int) -> Bool
    {
        // D5：changeCount 前置条件
        guard pasteboard.changeCount == expectedChangeCount else
        {
            logger.info("ChangeCount mismatch, skip replace: expected=\(expectedChangeCount, privacy: .public)")
            return false
        }

        pasteboard.clearContents()
        pasteboard.setString(newPath, forType: .string)

        // D4：标记自我写入
        let newChangeCount = pasteboard.changeCount
        suppressor.markSelfWrite(changeCount: newChangeCount)

        logger.info("Clipboard replaced: changeCount=\(newChangeCount, privacy: .public)")
        return true
    }
}
