import AppKit
import Foundation

/// 剪贴板轮询监听器。
///
/// 使用 Timer 轮询 NSPasteboard.changeCount，当变化时通过 ContentReader
/// 读取内容，并经 Deduplicator 过滤重复，最后通过 onPasteboardChange 回调通知。
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

    /// 当检测到剪贴板变化（且非重复内容）时调用
    var onPasteboardChange: ((ClipContent) -> Void)?

    /// - Parameters:
    ///   - pasteboard: 被监听的 pasteboard，默认为 .general
    ///   - contentReader: 内容读取器，默认为 ContentReader()
    ///   - deduplicator: 去重器，默认为 Deduplicator()
    init(pasteboard: NSPasteboard = .general,
         contentReader: ContentReader = ContentReader(),
         deduplicator: Deduplicator = Deduplicator()) {
        self.pasteboard = pasteboard
        self.contentReader = contentReader
        self.deduplicator = deduplicator
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
    @objc func handlePasteboardChange() {
        let current = pasteboard.changeCount
        guard current != lastChangeCount else {
            return
        }
        lastChangeCount = current

        guard let content = contentReader.readContent(from: pasteboard) else {
            return
        }
        guard !deduplicator.isDuplicate(content) else {
            return
        }
        deduplicator.updateLastContent(content)
        onPasteboardChange?(content)
    }
}
