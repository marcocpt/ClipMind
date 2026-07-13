import AppKit
import Foundation

/// 剪贴板轮询监听器。
///
/// 使用 Timer 轮询 NSPasteboard.changeCount，当变化时通过 ContentReader
/// 读取内容，并经 Deduplicator 过滤重复，最后通过 onPasteboardChange 回调通知。
/// 处理流程：黑名单检查 → 敏感内容检测 → 去重 → 回调通知。
final class PasteboardWatcher: NSObject {
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

    /// 黑名单服务
    private let blacklistService: BlacklistService

    /// 敏感内容检测器
    private let sensitiveDetector: SensitiveDetector

    /// 前台应用检测器
    private let appDetector: AppDetector

    /// 当检测到剪贴板变化（且非重复内容）时调用
    var onPasteboardChange: ((ClipContent) -> Void)?

    /// - Parameters:
    ///   - pasteboard: 被监听的 pasteboard，默认为 .general
    ///   - contentReader: 内容读取器，默认为 ContentReader()
    ///   - deduplicator: 去重器，默认为 Deduplicator()
    ///   - blacklistService: 黑名单服务，默认为 BlacklistService()
    ///   - sensitiveDetector: 敏感内容检测器，默认为 SensitiveDetector()
    ///   - appDetector: 前台应用检测器，默认为 AppDetector()
    init(pasteboard: NSPasteboard = .general,
         contentReader: ContentReader = ContentReader(),
         deduplicator: Deduplicator = Deduplicator(),
         blacklistService: BlacklistService = BlacklistService(),
         sensitiveDetector: SensitiveDetector = SensitiveDetector(),
         appDetector: AppDetector = AppDetector()) {
        self.pasteboard = pasteboard
        self.contentReader = contentReader
        self.deduplicator = deduplicator
        self.blacklistService = blacklistService
        self.sensitiveDetector = sensitiveDetector
        self.appDetector = appDetector
        self.lastChangeCount = pasteboard.changeCount
        super.init()
    }

    /// 启动轮询监听
    /// - Parameter interval: 轮询间隔，默认 0.5s
    func startWatching(interval: TimeInterval = 0.5) {
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
    func stopWatching() {
        timer?.invalidate()
        timer = nil
    }

    /// 轮询回调：检测 changeCount 变化，读取并去重内容
    /// 处理顺序：黑名单检查 → 敏感内容检测 → 去重 → 回调
    @objc func handlePasteboardChange() {
        let current = pasteboard.changeCount
        guard current != lastChangeCount else {
            return
        }
        lastChangeCount = current

        // 黑名单检查：来源应用在黑名单中则静默忽略
        if let appInfo = appDetector.currentFrontmostApp(),
           blacklistService.contains(bundleId: appInfo.bundleId) {
            LogCategory.privacy.info("黑名单应用 \(appInfo.bundleId)，静默忽略")
            return
        }

        guard let content = contentReader.readContent(from: pasteboard) else {
            return
        }

        // 敏感内容检测：检测到则不入库，并发送通知
        if case .text(let text) = content, sensitiveDetector.detect(text) {
            LogCategory.privacy.info("检测到敏感内容，已忽略")
            NotificationManager.sendSensitiveContentIgnoredNotification()
            return
        }

        guard !deduplicator.isDuplicate(content) else {
            return
        }
        deduplicator.updateLastContent(content)
        onPasteboardChange?(content)
    }
}
