import Combine
import Foundation

/// UI 层剪贴历史仓库。
///
/// 包装 EncryptedStore 的读取操作，并监听 ClipCaptureService.clipDidUpdateNotification
/// 自动刷新 clips，供 SwiftUI 视图观察。
final class ClipStore: ObservableObject {
    @Published var clips: [ClipItem] = []

    private var store: EncryptedStore?
    private var observer: NSObjectProtocol?

    init() {
        do {
            store = try EncryptedStore()
            loadClips()
        } catch {
            LogCategory.storage.error("EncryptedStore 初始化失败: \(error.localizedDescription)")
            store = nil
        }
        observer = NotificationCenter.default.addObserver(
            forName: ClipCaptureService.clipDidUpdateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.loadClips()
        }
    }

    deinit {
        if let observer = observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    /// 从 EncryptedStore 加载全部剪贴历史
    func loadClips() {
        guard let store = store else {
            clips = []
            return
        }
        do {
            clips = try store.loadAll()
        } catch {
            LogCategory.storage.error("加载剪贴历史失败: \(error.localizedDescription)")
            clips = []
        }
    }
}
