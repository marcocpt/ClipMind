import AppKit
import Foundation

/// 剪贴板轮询监听器。
///
/// 使用 Timer 轮询 NSPasteboard.changeCount，当变化时通过 ContentReader
/// 读取内容，并经 Deduplicator 过滤重复，然后经 CaptureEventBuilder
/// 构造不可变 CaptureEvent，最终通过 onPasteboardChange 回调通知。
///
/// F-11 例外（D6）：onPasteboardChange 回调参数从 ClipContent 扩展为
/// CaptureEvent，使 F1.x 与 F2.1 分支共享同一事件快照。
///
/// 处理流程：changeCount 检测 → 读取内容 → 去重 → B0 构造事件 → 回调通知。
/// 黑名单与敏感检查已迁移到 CaptureEventBuilder（D2 只跑一次）。
final class PasteboardWatcher: NSObject
{
    /// 当前轮询定时器（仅供测试观察，外部不应修改）
    private(set) var timer: Timer?

    /// 上次观察到的 changeCount
    private var lastChangeCount: Int

    /// 被监听的 pasteboard（默认为系统通用剪贴板，测试时可注入）
    private let pasteboard: NSPasteboard

    /// 内容读取器
    private let contentReader: ContentReader

    /// 去重器
    private let deduplicator: Deduplicator

    /// 捕获事件构造器（B0，D6/D23）
    /// 为 nil 时回退为最小事件（仅含 content 与 changeCount），保证 F1.x 既有测试兼容
    private let eventBuilder: CaptureEventBuilder?

    /// 当检测到剪贴板变化（且非重复内容）时调用
    /// F-11 例外：回调参数从 ClipContent 扩展为 CaptureEvent
    var onPasteboardChange: ((CaptureEvent) -> Void)?

    /// - Parameters:
    ///   - pasteboard: 被监听的 pasteboard，默认为 .general
    ///   - contentReader: 内容读取器，默认为 ContentReader()
    ///   - deduplicator: 去重器，默认为 Deduplicator()
    ///   - eventBuilder: 捕获事件构造器（B0），为 nil 时回退最小事件
    init(pasteboard: NSPasteboard = .general,
         contentReader: ContentReader = ContentReader(),
         deduplicator: Deduplicator = Deduplicator(),
         eventBuilder: CaptureEventBuilder? = nil)
    {
        self.pasteboard = pasteboard
        self.contentReader = contentReader
        self.deduplicator = deduplicator
        self.eventBuilder = eventBuilder
        self.lastChangeCount = pasteboard.changeCount
        super.init()
    }

    /// 启动轮询监听
    /// - Parameter interval: 轮询间隔，默认 0.5s
    func startWatching(interval: TimeInterval = 0.5)
    {
        stopWatching()
        let timer = Timer(
            timeInterval: interval,
            target: self,
            selector: #selector(handlePasteboardChange),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    /// 停止轮询监听
    func stopWatching()
    {
        timer?.invalidate()
        timer = nil
    }

    /// 轮询回调：检测 changeCount 变化，读取并去重内容，构造 CaptureEvent
    @objc func handlePasteboardChange()
    {
        let current = pasteboard.changeCount
        guard current != lastChangeCount else
        {
            return
        }
        lastChangeCount = current

        guard let content = contentReader.readContent(from: pasteboard) else
        {
            return
        }

        guard !deduplicator.isDuplicate(content) else
        {
            return
        }
        deduplicator.updateLastContent(content)

        let event: CaptureEvent
        if let builder = eventBuilder
        {
            guard let built = builder.build(content: content, changeCount: current) else
            {
                LogCategory.capture.logger.debug("EventBuilder returned nil, skipping")
                return
            }
            event = built
        } else {
            // F1.x 兼容回退：构造最小事件
            event = CaptureEvent(
                id: UUID().uuidString,
                changeCount: current,
                content: content,
                bundleId: "unknown",
                appName: "Unknown",
                blacklisted: false,
                sensitiveResult: .none,
                f1xConfigSnapshot: F1xConfigSnapshot(blacklistBundleIds: []),
                f2xConfigSnapshot: F2xConfigSnapshot(
                    isEnabled: false,
                    saveDirectory: "",
                    whitelistBundleIds: [],
                    fileFormat: .markdown,
                    lengthThreshold: 50,
                    fileNameLength: 20,
                    sensitiveFilterEnabled: true,
                    pathFormat: .plainPath
                ),
                timestamp: Date()
            )
        }

        onPasteboardChange?(event)
    }
}
