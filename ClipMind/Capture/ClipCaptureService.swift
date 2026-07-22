import Foundation

/// 剪贴板捕获编排服务。
///
/// 连接 PasteboardWatcher（剪贴板变化检测）与 EncryptedStore（持久化），
/// 并通过 ClassificationService 对文本内容进行分类，最终发送通知刷新 UI。
///
/// F2.1 适配（D6）：接收 CaptureEvent 而非 ClipContent。
/// F1.x 过滤逻辑（黑名单 D3 + 敏感）从 PasteboardWatcher 迁移到此处，
/// 保留 F1.x 既有可观察行为（黑名单/敏感内容不入库）。
///
/// 处理流程（由 PasteboardWatcher 回调触发）：
/// 1. 检查 event.blacklisted → 日志并返回（D3 黑名单优先）
/// 2. 检查 event.sensitiveResult.isSensitive → 日志、通知、返回
/// 3. 取 event.content 经 ClassificationService 分类
/// 4. 创建 ClipItem
/// 5. 调用 autoSaveService.handle(event:) 派发 F2.1 分支（D7，可选）
/// 6. 存入 EncryptedStore（F1.x 入库流程不变）
/// 7. 发送 clipDidUpdateNotification 通知 UI 刷新
final class ClipCaptureService
{
    /// 入库后发送的通知名称，UI 监听此通知以刷新历史列表
    static let clipDidUpdateNotification = Notification.Name("ClipMindClipDidUpdate")

    private let watcher: PasteboardWatcher
    private let store: EncryptedStore
    private let classifier: ClassificationService
    private let appDetector: AppDetector

    /// F2.1 自动保存服务（可选，D7 异步派发）。
    /// 为 nil 时（F1.x 既有行为）ClipCaptureService 行为完全不变。
    /// 使用 AnyObject + 运行时 cast 到 AutoSaveServiceProtocol，避免直接依赖具体类型。
    var autoSaveService: AnyObject?

    /// 入库完成回调（测试观察用）
    var onClipStored: ((ClipItem) -> Void)?

    /// - Parameters:
    ///   - watcher: 剪贴板监听器
    ///   - store: 加密存储
    ///   - classifier: 内容分类服务
    ///   - appDetector: 前台应用检测器
    init(watcher: PasteboardWatcher,
         store: EncryptedStore,
         classifier: ClassificationService,
         appDetector: AppDetector = AppDetector())
    {
        self.watcher = watcher
        self.store = store
        self.classifier = classifier
        self.appDetector = appDetector
        watcher.onPasteboardChange = { [weak self] event in
            self?.handleCaptureEvent(event)
        }
    }

    /// 启动剪贴板监听
    func start()
    {
        watcher.startWatching()
    }

    /// 停止剪贴板监听
    func stop()
    {
        watcher.stopWatching()
    }

    /// 处理捕获事件：黑名单检查 → 敏感检查 → 分类 → 入库 → F2.1 派发 → 通知
    func handleCaptureEvent(_ event: CaptureEvent)
    {
        // D3：黑名单优先，命中不入库
        if event.blacklisted
        {
            LogCategory.privacy.logger.info(
                "Blacklisted app, skip storage: changeCount=\(event.changeCount, privacy: .public)"
            )
            return
        }

        // 敏感内容不入库（保留 F1.x 既有行为）
        if event.sensitiveResult.isSensitive
        {
            LogCategory.privacy.logger.info(
                "Sensitive content detected, skip storage: changeCount=\(event.changeCount, privacy: .public)"
            )
            NotificationManager.sendSensitiveContentIgnoredNotification()
            return
        }

        let item = makeClipItem(from: event)

        // 派发 F2.1 分支（D7 异步，autoSaveService 通过协议调用）
        if let autoSave = autoSaveService as? AutoSaveServiceProtocol
        {
            autoSave.handle(event: event)
        }

        saveAndNotify(item: item)
    }

    /// 根据 event.content 创建 ClipItem（分类 + 工厂方法）
    private func makeClipItem(from event: CaptureEvent) -> ClipItem
    {
        let bundleId = event.bundleId
        let appName = event.appName

        switch event.content
        {
        case .text(let text):
            let contentType = classifier.classify(text)
            LogCategory.capture.logger.info("""
            Captured text: contentLength=\(text.count, privacy: .public), \
            type=\(contentType.rawValue, privacy: .public)
            """)
            return ClipItem.makeText(
                text,
                contentType: contentType,
                sourceApp: bundleId,
                sourceAppName: appName
            )
        case .image(let data):
            LogCategory.capture.logger.info(
                "Captured image: contentLength=\(data.count, privacy: .public)"
            )
            return ClipItem.makeImage(
                data,
                contentType: .other,
                sourceApp: bundleId,
                sourceAppName: appName
            )
        case .filePath(let urls):
            LogCategory.capture.logger.info(
                "Captured filePath: count=\(urls.count, privacy: .public)"
            )
            return ClipItem.makeFilePath(
                urls,
                contentType: .other,
                sourceApp: bundleId,
                sourceAppName: appName
            )
        }
    }

    /// 存入 EncryptedStore 并发送通知
    private func saveAndNotify(item: ClipItem)
    {
        do {
            try store.save(item)
            LogCategory.capture.logger.info(
                "ClipItem stored: type=\(item.contentType.rawValue, privacy: .public)"
            )
            NotificationCenter.default.post(name: Self.clipDidUpdateNotification, object: nil)
            onClipStored?(item)
        } catch {
            LogCategory.storage.logger.error(
                "Storage failed: errorCode=\(error.localizedDescription, privacy: .public)"
            )
        }
    }
}

/// AutoSaveService 协议（用于 ClipCaptureService 解耦）
protocol AutoSaveServiceProtocol
{
    func handle(event: CaptureEvent)
}
