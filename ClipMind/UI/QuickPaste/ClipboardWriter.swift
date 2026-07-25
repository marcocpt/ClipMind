import AppKit
import Foundation

/// 剪贴板写入协议（依赖注入，便于测试 mock）。
///
/// Phase 3 仅支持文本写入；图片/文件路径类型在 PasteCoordinator 层拦截（不调用写入）。
protocol ClipboardWriting: AnyObject
{
    /// 将文本写入剪贴板。
    /// - Parameter text: 待写入的文本
    /// - Returns: 写入是否成功
    func write(text: String) -> Bool
}

/// 剪贴板写入模块默认实现（使用 NSPasteboard）。
///
/// 设计文档第 3.7 节。仅写入文本类型，写入失败时返回 false 由协调器处理。
/// 日志仅记录元数据（文本长度），不记录原文（NFR-003 安全性）。
///
/// F1.11 Bug 3 修复：注入共享的 `SelfWriteSuppressor`，写入成功后调用
/// `markSelfWrite(changeCount:)`。PasteboardWatcher 下次轮询时通过
/// `checkAndReset(changeCount:)` 命中并跳过捕获，避免应用自身写入的内容
/// 被误识别为"用户外部新复制"而重复入库。与 F2.1 的 ClipboardReplacer
/// 共用同一套自我写入抑制机制，确保两条路径行为一致。
final class ClipboardWriter: ClipboardWriting
{
    private let pasteboard: NSPasteboard

    /// 自我写入抑制器（可选）。生产环境由 `ClipMindApp` 注入共享实例，
    /// 与 `PasteboardWatcher` 共享；为 nil 时不进行抑制标记（向后兼容）。
    private let suppressor: SelfWriteSuppressor?

    /// - Parameters:
    ///   - pasteboard: NSPasteboard 实例（生产用 .general，测试注入隔离实例）
    ///   - suppressor: 自我写入抑制器（可选）。生产环境传入与 PasteboardWatcher
    ///     共享的实例；为 nil 时不进行抑制标记。
    init(pasteboard: NSPasteboard = .general, suppressor: SelfWriteSuppressor? = nil)
    {
        self.pasteboard = pasteboard
        self.suppressor = suppressor
    }

    func write(text: String) -> Bool
    {
        pasteboard.clearContents()
        let success = pasteboard.setString(text, forType: .string)
        if success {
            LogCategory.app.info("Clipboard written, length: \(text.count)")
            // F1.11 Bug 3：写入成功后标记自我写入，告知 PasteboardWatcher 跳过本次捕获。
            // changeCount 必须在写入完成后读取，才能拿到 setString 产生的新值。
            suppressor?.markSelfWrite(changeCount: pasteboard.changeCount)
        } else {
            LogCategory.app.error("Clipboard write failed")
        }
        return success
    }
}
