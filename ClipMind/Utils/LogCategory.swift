import Foundation
import os

/// 日志分类枚举。
///
/// 定义不同模块的日志分类，每个分类对应一个独立的 os.Logger 实例，
/// 便于在 Console.app 中按子系统（com.clipmind.app）和分类过滤日志。
enum LogCategory: String, CaseIterable {
    case capture = "Capture"
    case classify = "Classify"
    case search = "Search"
    case llm = "LLM"
    case storage = "Storage"
    case privacy = "Privacy"
    // swiftlint:disable:next identifier_name
    case ui = "UI"
    case app = "App"

    /// 该分类对应的 os.Logger 实例
    var logger: Logger {
        Logger(subsystem: "com.clipmind.app", category: rawValue)
    }
}
