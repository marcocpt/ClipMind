import AppKit
import Foundation

final class CaptureService: ObservableObject {
    let watcher: PasteboardWatcher
    private let store: EncryptedStore
    private let appDetector: AppDetector

    @Published private(set) var clips: [ClipItem] = []

    init(
        pasteboard: NSPasteboard = .general,
        store: EncryptedStore,
        appDetector: AppDetector = AppDetector()
    ) {
        let contentReader = ContentReader()
        let deduplicator = Deduplicator()
        let blacklistService = BlacklistService()
        let sensitiveDetector = SensitiveDetector()

        self.watcher = PasteboardWatcher(
            pasteboard: pasteboard,
            contentReader: contentReader,
            deduplicator: deduplicator,
            blacklistService: blacklistService,
            sensitiveDetector: sensitiveDetector,
            appDetector: appDetector
        )
        self.store = store
        self.appDetector = appDetector
    }

    init(
        watcher: PasteboardWatcher,
        store: EncryptedStore,
        appDetector: AppDetector = AppDetector()
    ) {
        self.watcher = watcher
        self.store = store
        self.appDetector = appDetector
    }

    func start() {
        loadExistingClips()
        watcher.onPasteboardChange = { [weak self] content in
            self?.handleCapturedContent(content)
        }
        watcher.startWatching()
    }

    func stop() {
        watcher.stopWatching()
    }

    private func loadExistingClips() {
        do {
            clips = try store.loadAll()
        } catch {
            LogCategory.capture.error("加载历史剪贴内容失败: \(error.localizedDescription)")
            clips = []
        }
    }

    private func handleCapturedContent(_ content: ClipContent) {
        let appInfo = appDetector.currentFrontmostApp()

        let item = ClipItem(
            id: UUID(),
            content: content,
            contentType: .other,
            sourceApp: appInfo?.bundleId ?? "unknown",
            sourceAppName: appInfo?.appName ?? "Unknown",
            timestamp: Date(),
            summary: nil,
            translation: nil,
            rewrite: nil,
            todos: nil,
            embeddings: nil
        )

        do {
            try store.save(item)
            LogCategory.capture.info("捕获并保存剪贴内容, type: \(String(describing: content.swiftType))")
        } catch {
            LogCategory.storage.error("保存剪贴内容失败: \(error.localizedDescription)")
            return
        }

        clips.insert(item, at: 0)
    }
}

private extension ClipContent {
    var swiftType: String {
        switch self {
        case .text: return "text"
        case .image: return "image"
        case .filePath: return "filePath"
        }
    }
}
