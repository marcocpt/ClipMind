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
final class ClipboardWriter: ClipboardWriting
{
    private let pasteboard: NSPasteboard

    /// - Parameter pasteboard: NSPasteboard 实例（生产用 .general，测试注入隔离实例）
    init(pasteboard: NSPasteboard = .general)
    {
        self.pasteboard = pasteboard
    }

    func write(text: String) -> Bool
    {
        pasteboard.clearContents()
        let success = pasteboard.setString(text, forType: .string)
        if success {
            LogCategory.app.info("Clipboard written, length: \(text.count)")
        } else {
            LogCategory.app.error("Clipboard write failed")
        }
        return success
    }
}
