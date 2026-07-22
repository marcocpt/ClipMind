import Foundation

/// 剪贴板捕获编排服务。
///
/// 连接 PasteboardWatcher（剪贴板变化检测）与 EncryptedStore（持久化），
/// 并通过 ClassificationService 对文本内容进行分类，最终发送通知刷新 UI。
///
/// 处理流程（由 PasteboardWatcher 回调触发）：
/// 1. 获取前台 App 信息（bundleId / appName）
/// 2. 文本内容经 ClassificationService 分类
/// 3. 创建 ClipItem
/// 4. 存入 EncryptedStore
/// 5. 发送 clipDidUpdateNotification 通知 UI 刷新
final class ClipCaptureService {
    /// 入库后发送的通知名称，UI 监听此通知以刷新历史列表
    static let clipDidUpdateNotification = Notification.Name("ClipMindClipDidUpdate")

    private let watcher: PasteboardWatcher
    private let store: EncryptedStore
    private let classifier: ClassificationService
    private let appDetector: AppDetector

    /// - Parameters:
    ///   - watcher: 剪贴板监听器（生产环境使用默认 `.general` pasteboard，测试时注入）
    ///   - store: 加密存储
    ///   - classifier: 内容分类服务
    ///   - appDetector: 前台应用检测器
    init(watcher: PasteboardWatcher,
         store: EncryptedStore,
         classifier: ClassificationService,
         appDetector: AppDetector = AppDetector()) {
        self.watcher = watcher
        self.store = store
        self.classifier = classifier
        self.appDetector = appDetector
        watcher.onPasteboardChange = { [weak self] event in
            self?.handleClipContent(event.content)
        }
    }

    /// 启动剪贴板监听
    func start() {
        watcher.startWatching()
    }

    /// 停止剪贴板监听
    func stop() {
        watcher.stopWatching()
    }

    /// 处理剪贴板变化内容：分类 → 创建 ClipItem → 入库 → 通知
    private func handleClipContent(_ content: ClipContent) {
        let (bundleId, appName) = appDetector.currentFrontmostApp() ?? ("unknown", "Unknown")

        let item: ClipItem
        switch content {
        case .text(let text):
            let contentType = classifier.classify(text)
            item = ClipItem.makeText(
                text,
                contentType: contentType,
                sourceApp: bundleId,
                sourceAppName: appName
            )
            LogCategory.capture.info("捕获文本内容 length=\(text.count) type=\(contentType.rawValue)")
        case .image(let data):
            item = ClipItem.makeImage(
                data,
                contentType: .other,
                sourceApp: bundleId,
                sourceAppName: appName
            )
            LogCategory.capture.info("捕获图片内容 size=\(data.count) bytes")
        case .filePath(let urls):
            item = ClipItem.makeFilePath(
                urls,
                contentType: .other,
                sourceApp: bundleId,
                sourceAppName: appName
            )
            LogCategory.capture.info("捕获文件路径 count=\(urls.count)")
        }

        do {
            try store.save(item)
            LogCategory.capture.info("ClipItem 已入库: type=\(item.contentType.rawValue), source=\(appName)")
            NotificationCenter.default.post(name: Self.clipDidUpdateNotification, object: nil)
        } catch {
            LogCategory.storage.error("ClipItem 入库失败: \(error.localizedDescription)")
        }
    }
}
