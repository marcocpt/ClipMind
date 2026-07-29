import Combine
import Foundation

/// UI 层剪贴历史仓库。
///
/// 包装 EncryptedStore 的读取操作，并监听 ClipCaptureService.clipDidUpdateNotification
/// 和 .clipTagsDidUpdate 自动刷新 clips，供 SwiftUI 视图观察。
final class ClipStore: ObservableObject {
    @Published var clips: [ClipItem] = []

    private var store: EncryptedStore?
    private var observers: [NSObjectProtocol] = []

    init(store: EncryptedStore? = nil) {
        if let store = store {
            self.store = store
            loadClips()
        } else {
            do {
                self.store = try EncryptedStore()
                loadClips()
            } catch {
                LogCategory.storage.error("EncryptedStore 初始化失败: \(error.localizedDescription)")
                self.store = nil
            }
        }
        let center = NotificationCenter.default
        observers.append(
            center.addObserver(
                forName: ClipCaptureService.clipDidUpdateNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.loadClips()
            }
        )
        observers.append(
            center.addObserver(
                forName: .clipTagsDidUpdate,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.loadClips()
            }
        )
    }

    deinit {
        for observer in observers {
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

    /// 更新指定 ClipItem 到数据库并刷新 clips 列表
    /// - Parameter item: 包含更新内容的 ClipItem
    func updateClip(_ item: ClipItem) {
        do {
            try store?.update(item)
            if let index = clips.firstIndex(where: { $0.id == item.id }) {
                clips[index] = item
            } else {
                clips.insert(item, at: 0)
            }
        } catch {
            LogCategory.storage.error("Failed to update clip: \(error.localizedDescription)")
        }
    }
}
