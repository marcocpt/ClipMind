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

    /// D10：EEXIST 重试次数上限，与 ConflictResolver.maxAttempts 一致。
    private static let maxEexistRetries = 999

    /// 自动保存错误通知名称（D13 目录异常分级处理，AC-09 弹窗触发）
    static let errorNotification = Notification.Name("ClipMindAutoSaveError")

    /// 保存完成通知名称（含成功与跳过，供测试条件等待替代固定 sleep）
    static let savedNotification = Notification.Name("ClipMindAutoSaveSaved")

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
            skipDebug(eventId: event.id, reason: "F2.1 disabled")
            return
        }
        guard !event.blacklisted else
        {
            skipDebug(eventId: event.id, reason: "blacklisted app")
            return
        }
        guard config.isWhitelisted(bundleId: event.bundleId) else
        {
            skipDebug(eventId: event.id, reason: "not in whitelist")
            return
        }
        guard case .text(let text) = event.content else
        {
            skipDebug(eventId: event.id, reason: "non-text content (D12)")
            return
        }
        guard text.utf8.count <= Self.maxContentLength else
        {
            skipInfo(
                eventId: event.id,
                message: "Skip: content too large (D12), length=\(text.count) eventId=\(event.id)"
            )
            return
        }
        // D12：纯空白内容（只含空格/换行/Tab）跳过，避免写入无意义文件
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else
        {
            skipInfo(
                eventId: event.id,
                message: "Skip: blank-only content (D12), length=\(text.count) eventId=\(event.id)"
            )
            return
        }
        guard text.count >= config.lengthThreshold else
        {
            skipDebug(eventId: event.id, reason: "below threshold")
            return
        }
        if config.sensitiveFilterEnabled && event.sensitiveResult.isSensitive
        {
            skipInfo(eventId: event.id, message: "Skip: sensitive content detected, eventId=\(event.id)")
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
            logger.info("""
            Skip: changeCount expired (D24), eventId=\(event.id, privacy: .public) \
            expected=\(event.changeCount, privacy: .public) \
            current=\(self.pasteboard.changeCount, privacy: .public)
            """)
            postSavedNotification(eventId: event.id, skipped: true)
            return
        }
        let baseFileURL = makeBaseFileURL(event: event, text: text, config: config)

        // D10：EEXIST 重试——O_EXCL 检测到并发竞态时，递增序号重试
        guard let savedURL = writeWithEexistRetry(event: event, text: text, baseFileURL: baseFileURL) else
        {
            postSavedNotification(eventId: event.id, skipped: true)
            return
        }

        let contentLength = text.count
        logger.info("""
        Saved: result=success, \
        contentLength=\(contentLength, privacy: .public), \
        eventId=\(event.id, privacy: .public), \
        changeCount=\(event.changeCount, privacy: .public)
        """)

        let formattedPath = pathFormatter.format(url: savedURL, format: config.pathFormat)
        let replaced = clipboardReplacer.replace(with: formattedPath, expectedChangeCount: event.changeCount)
        if !replaced
        {
            logger.info("""
            Clipboard replace skipped (D5), eventId=\(event.id, privacy: .public) \
            expected=\(event.changeCount, privacy: .public) \
            current=\(self.pasteboard.changeCount, privacy: .public)
            """)
        }
        postSavedNotification(eventId: event.id, fileName: savedURL.lastPathComponent, skipped: false)
    }

    private func makeBaseFileURL(event: CaptureEvent, text: String, config: F2xConfigSnapshot) -> URL
    {
        let fileName = fileNameGenerator.generate(
            content: text,
            appName: event.appName,
            fileFormat: config.fileFormat,
            fileNameLength: config.fileNameLength,
            timestamp: event.timestamp
        )
        let directory = URL(fileURLWithPath: (config.saveDirectory as NSString).expandingTildeInPath)
        return directory.appendingPathComponent(fileName)
    }

    /// D10：EEXIST 重试循环——每次都从 baseFileURL 开始 resolve，避免后缀叠加（如 hello-1-1.md）。
    /// 成功时返回写入的 URL；失败时记录日志并返回 nil（D24 不重试其他错误）。
    private func writeWithEexistRetry(
        event: CaptureEvent,
        text: String,
        baseFileURL: URL
    ) -> URL?
    {
        var attempt = 0
        while true
        {
            let candidateURL: URL
            do {
                candidateURL = try conflictResolver.resolve(baseFileURL)
            } catch {
                logger.error("""
                Conflict: eventId=\(event.id, privacy: .public) \
                code=\(String(describing: error), privacy: .public)
                """)
                return nil
            }
            do {
                try fileWriter.write(content: text, to: candidateURL)
                return candidateURL
            } catch AutoSaveError.fileAlreadyExists {
                // 并发竞态：resolve 检测与 write 之间文件被创建，递增序号重试（D10）
                attempt += 1
                if attempt >= Self.maxEexistRetries
                {
                    logger.error("""
                    EEXIST retries exhausted (D10), eventId=\(event.id, privacy: .public) \
                    attempts=\(attempt, privacy: .public)
                    """)
                    return nil
                }
                logger.info("""
                Retry on EEXIST (D10), eventId=\(event.id, privacy: .public) \
                attempt=\(attempt, privacy: .public)
                """)
                continue
            } catch {
                logger.error("""
                Write failed: eventId=\(event.id, privacy: .public) \
                code=\(String(describing: error), privacy: .public)
                """)
                // D13：目录异常分级处理，发送错误通知触发弹窗（AC-09）
                NotificationCenter.default.post(
                    name: Self.errorNotification,
                    object: nil,
                    userInfo: ["errorCode": error.localizedDescription]
                )
                return nil
            }
        }
    }

    /// 发送保存完成通知（成功或跳过），供测试条件等待替代固定 sleep。
    private func postSavedNotification(eventId: String, fileName: String? = nil, skipped: Bool)
    {
        var userInfo: [String: Any] = ["eventId": eventId]
        if let fileName = fileName
        {
            userInfo["fileName"] = fileName
        }
        if skipped
        {
            userInfo["skipped"] = true
        }
        NotificationCenter.default.post(name: Self.savedNotification, object: nil, userInfo: userInfo)
    }

    /// 记录 debug 级别跳过日志并发送跳过通知。
    private func skipDebug(eventId: String, reason: String)
    {
        logger.debug("Skip: \(reason, privacy: .public)")
        postSavedNotification(eventId: eventId, skipped: true)
    }

    /// 记录 info 级别跳过日志并发送跳过通知。
    private func skipInfo(eventId: String, message: String)
    {
        logger.info("\(message, privacy: .public)")
        postSavedNotification(eventId: eventId, skipped: true)
    }
}

// MARK: - AutoSaveServiceProtocol 遵循（F2.1 任务 3，D22 不修改公共接口）

extension AutoSaveService: AutoSaveServiceProtocol {}
