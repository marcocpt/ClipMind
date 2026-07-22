import Foundation

/// 捕获事件不可变快照（D1 事件驱动模型，D6 配置快照不可变）。
///
/// 在 PasteboardWatcher 检测到剪贴板变化时构造，承载原始内容、来源 App 信息、
/// 敏感识别结果（D2 只执行一次）、F1.x 与 F2.1 配置快照（D23 事件构造阶段读取）。
/// 所有属性为 `let`，满足 FR-016 不可变快照契约。实现 `Sendable` 保证跨并发边界安全。
struct CaptureEvent: @unchecked Sendable
{
    let id: String
    let changeCount: Int
    let content: ClipContent
    let bundleId: String
    let appName: String
    let blacklisted: Bool
    let sensitiveResult: SensitiveMatchResult
    let f1xConfigSnapshot: F1xConfigSnapshot
    let f2xConfigSnapshot: F2xConfigSnapshot
    let timestamp: Date

    /// 内容长度（字符数，D12 100KB 上限判断依据）。
    var contentLength: Int
    {
        switch content
        {
        case .text(let text):
            return text.count
        case .image(let data):
            return data.count
        case .filePath:
            return 0
        }
    }

    init(
        id: String = UUID().uuidString,
        changeCount: Int,
        content: ClipContent,
        bundleId: String,
        appName: String,
        blacklisted: Bool,
        sensitiveResult: SensitiveMatchResult,
        f1xConfigSnapshot: F1xConfigSnapshot,
        f2xConfigSnapshot: F2xConfigSnapshot,
        timestamp: Date = Date()
    )
    {
        self.id = id
        self.changeCount = changeCount
        self.content = content
        self.bundleId = bundleId
        self.appName = appName
        self.blacklisted = blacklisted
        self.sensitiveResult = sensitiveResult
        self.f1xConfigSnapshot = f1xConfigSnapshot
        self.f2xConfigSnapshot = f2xConfigSnapshot
        self.timestamp = timestamp
    }
}

/// F1.x 配置快照（D3 黑名单优先判断依据）。
struct F1xConfigSnapshot: Sendable
{
    let blacklistBundleIds: [String]
}
