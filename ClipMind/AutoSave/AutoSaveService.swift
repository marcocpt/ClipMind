import AppKit
import Foundation

/// F2.1 自动保存主服务（D7 串行队列 + D12 边界 + D24 不重试 + D3 黑名单优先）。
public final class AutoSaveService
{
    /// 专用串行队列（D7：文件 I/O 异步串行，qos: .utility）。
    public let queue: DispatchQueue

    private let settingsStore: AutoSaveSettingsStore
    private let pasteboard: NSPasteboard
    private let suppressor: SelfWriteSuppressor
    private let fileNameGenerator: FileNameGenerator
    private let conflictResolver: ConflictResolver
    private let fileWriter: FileWriter
    private let pathFormatter: FilePathFormatter
    private let clipboardReplacer: ClipboardReplacer
    private let logger = LogCategory.capture.logger

    /// D12：内容上限 100KB。
    private static let maxContentLength = 100 * 1024

    public init(
        settingsStore: AutoSaveSettingsStore,
        pasteboard: NSPasteboard,
        suppressor: SelfWriteSuppressor
    )
    {
        self.settingsStore = settingsStore
        self.pasteboard = pasteboard
        self.suppressor = suppressor
        self.fileNameGenerator = FileNameGenerator()
        self.conflictResolver = ConflictResolver()
        self.fileWriter = FileWriter()
        self.pathFormatter = FilePathFormatter()
        self.clipboardReplacer = ClipboardReplacer(pasteboard: pasteboard, suppressor: suppressor)
        self.queue = DispatchQueue(label: "com.clipmind.f2x.autosave", qos: .utility)
    }

    /// 处理捕获事件（D7 轻量检查同步 + 文件 I/O 异步串行）。
    /// 注：CaptureEvent 为 internal 类型，故 handle 为 internal（@testable 可访问）。
    func handle(event: CaptureEvent)
    {
        let config = event.f2xConfigSnapshot
        guard config.isEnabled else
        {
            logger.debug("Skip: F2.1 disabled")
            return
        }
        guard !event.blacklisted else
        {
            logger.debug("Skip: blacklisted app")
            return
        }
        guard config.isWhitelisted(bundleId: event.bundleId) else
        {
            logger.debug("Skip: not in whitelist")
            return
        }
        guard case .text(let text) = event.content else
        {
            logger.debug("Skip: non-text content (D12)")
            return
        }
        guard text.utf8.count <= Self.maxContentLength else
        {
            logger.info("Skip: content too large (D12), length=\(text.count, privacy: .public)")
            return
        }
        guard text.count >= config.lengthThreshold else
        {
            logger.debug("Skip: below threshold")
            return
        }
        if config.sensitiveFilterEnabled && event.sensitiveResult.isSensitive
        {
            logger.info("Skip: sensitive content detected")
            return
        }
        queue.async { [weak self] in
            self?.performSave(event: event, text: text, config: config)
        }
    }

    private func performSave(event: CaptureEvent, text: String, config: F2xConfigSnapshot)
    {
        guard pasteboard.changeCount == event.changeCount else
        {
            logger.info("Skip: changeCount expired (D24), eventId=\(event.id, privacy: .public)")
            return
        }
        let fileName = fileNameGenerator.generate(
            content: text,
            appName: event.appName,
            fileFormat: config.fileFormat,
            fileNameLength: config.fileNameLength,
            timestamp: event.timestamp
        )
        let directory = URL(fileURLWithPath: (config.saveDirectory as NSString).expandingTildeInPath)
        var fileURL = directory.appendingPathComponent(fileName)
        do {
            fileURL = try conflictResolver.resolve(fileURL)
        } catch {
            logger.error("Conflict: eventId=\(event.id, privacy: .public) code=\(error._code, privacy: .public)")
            return
        }
        do {
            try fileWriter.write(content: text, to: fileURL)
        } catch {
            logger.error("Write failed: eventId=\(event.id, privacy: .public) code=\(error._code, privacy: .public)")
            return
        }
        let formattedPath = pathFormatter.format(url: fileURL, format: config.pathFormat)
        let replaced = clipboardReplacer.replace(with: formattedPath, expectedChangeCount: event.changeCount)
        if !replaced
        {
            logger.info("Clipboard replace skipped (D5), eventId=\(event.id, privacy: .public)")
        }
    }
}
