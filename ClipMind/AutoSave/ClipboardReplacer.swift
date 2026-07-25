import AppKit
import Foundation

/// 剪贴板替换器（D5 changeCount 前置条件 + D4 markSelfWrite）。
///
/// F2.1.2：替换剪贴板时，除了写入文件路径作为 `public.utf8-plain-text` 主格式，
/// 还会把原始文本作为 `public.html` 写入，让其他剪贴板 app（如 Paste）能捕获到原文。
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
    ///
    /// - Parameters:
    ///   - newPath: 文件路径，作为 `public.utf8-plain-text` 主格式写入。
    ///   - originalText: 原始复制文本，非空时作为 `public.html` 写入以保留原文。
    ///                   传 nil 或空字符串时只写入文件路径（向后兼容）。
    ///   - expectedChangeCount: 前置条件，必须与当前 `pasteboard.changeCount` 一致。
    /// - Returns: 是否成功替换。
    @discardableResult
    public func replace(
        with newPath: String,
        originalText: String? = nil,
        expectedChangeCount: Int
    ) -> Bool
    {
        // D5：changeCount 前置条件
        guard pasteboard.changeCount == expectedChangeCount else
        {
            logger.info("""
            ChangeCount mismatch, skip replace: \
            expected=\(expectedChangeCount, privacy: .public) \
            current=\(self.pasteboard.changeCount, privacy: .public)
            """)
            return false
        }

        pasteboard.clearContents()
        pasteboard.setString(newPath, forType: .string)

        // F2.1.2：原始文本非空时，作为 HTML 格式写入保留原文
        // 解决 ChatGPT 网页复制按钮场景下，其他剪贴板 app（如 Paste）只能看到文件路径的问题
        if let originalText = originalText, !originalText.isEmpty
        {
            let html = Self.wrapAsHTML(originalText)
            pasteboard.setString(html, forType: .html)
        }

        // D4：标记自我写入
        let newChangeCount = pasteboard.changeCount
        suppressor.markSelfWrite(changeCount: newChangeCount)

        logger.info("Clipboard replaced: changeCount=\(newChangeCount, privacy: .public)")
        return true
    }

    /// 将原始文本包装为最小 HTML 文档，转义 HTML 特殊字符。
    /// 使用 `<pre>` 标签保留原始换行与空白格式。
    private static func wrapAsHTML(_ text: String) -> String
    {
        let escaped = text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
        return """
        <!DOCTYPE html>
        <html><head><meta charset="utf-8"></head>\
        <body><pre>\(escaped)</pre></body></html>
        """
    }
}
