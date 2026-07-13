import Foundation

/// 自动清理服务（T3.3）
///
/// 负责按配置周期自动清理超过保留期的剪贴板历史。
/// 设计规范 4.1 节状态机（已清理状态）和 5.4.1 节 EncryptedStore.cleanup 接口。
///
/// - 启动触发：应用启动时调用 `cleanupOnLaunch()` 执行一次清理
/// - 定时触发：`startPeriodicCleanup()` 启动定时器，默认每 24 小时清理一次
/// - 配置尊重：`autoCleanupEnabled=false` 时跳过清理；`cleanupDays` 控制保留天数
final class CleanupService {
    private let store: EncryptedStore
    private var settings: AppSettings
    private var timer: Timer?

    /// 初始化清理服务
    /// - Parameters:
    ///   - store: 加密存储实例
    ///   - settings: 应用配置（读取 autoCleanupEnabled 和 cleanupDays）
    init(store: EncryptedStore, settings: AppSettings) {
        self.store = store
        self.settings = settings
    }

    /// 更新配置（设置面板修改清理周期后调用）
    /// - Parameter settings: 新的应用配置
    func updateSettings(_ settings: AppSettings) {
        self.settings = settings
    }

    /// 执行一次清理，删除超过保留期的记录
    /// - Throws: EncryptedStore 清理失败时抛出
    func performCleanup() throws {
        guard settings.autoCleanupEnabled else {
            LogCategory.storage.debug("自动清理已禁用，跳过")
            return
        }
        let days = settings.cleanupDays
        LogCategory.storage.info("开始清理 \(days) 天前的记录")
        try store.cleanup(olderThan: days)
        LogCategory.storage.info("清理完成（保留周期 \(days) 天）")
    }

    /// 应用启动时触发清理，错误不向上传播（避免启动崩溃）
    func cleanupOnLaunch() {
        do {
            try performCleanup()
        } catch {
            LogCategory.storage.error("启动清理失败: \(error.localizedDescription)")
        }
    }

    /// 启动定时清理
    /// - Parameter interval: 清理间隔（秒），默认 24 小时
    func startPeriodicCleanup(interval: TimeInterval = 24 * 3600) {
        stopPeriodicCleanup()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.cleanupOnLaunch()
        }
        LogCategory.storage.info("已启动定时清理，间隔 \(Int(interval)) 秒")
    }

    /// 停止定时清理
    func stopPeriodicCleanup() {
        timer?.invalidate()
        if timer != nil {
            LogCategory.storage.info("已停止定时清理")
        }
        timer = nil
    }

    deinit {
        timer?.invalidate()
    }
}
