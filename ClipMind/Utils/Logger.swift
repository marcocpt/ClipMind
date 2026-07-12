import Foundation
import os

/// LogCategory 的日志级别扩展。
///
/// 提供统一的日志接口，封装 os.Logger 的调用细节。
/// 所有日志消息均以 `privacy: .public` 输出，确保在 Console.app 中可见。
extension LogCategory {
    /// 输出 DEBUG 级别日志
    /// - Parameter message: 日志消息
    func debug(_ message: String) {
        logger.debug("\(message, privacy: .public)")
    }

    /// 输出 INFO 级别日志
    /// - Parameter message: 日志消息
    func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
    }

    /// 输出 WARN 级别日志
    /// - Parameter message: 日志消息
    func warning(_ message: String) {
        logger.warning("\(message, privacy: .public)")
    }

    /// 输出 ERROR 级别日志
    /// - Parameter message: 日志消息
    func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
    }
}
