import Foundation

// MARK: - 通知名

extension Notification.Name
{
    /// 标签数据更新（迁移批次完成或 mutation 成功后发送）。
    static let clipTagsDidUpdate = Notification.Name("ClipMindClipTagsDidUpdate")

    /// 标签迁移需要重试（启动迁移失败时发送）。
    static let clipTagMigrationNeedsRetry = Notification.Name("ClipMindClipTagMigrationNeedsRetry")
}

// MARK: - 迁移协调器

/// 分批、幂等、可恢复的旧条目迁移协调器。
///
/// `resume()` 循环调用 `service.migrateNextBatch(limit:)`，每批有迁移产出时
/// 在主线程发送 `.clipTagsDidUpdate`，直到 `remainingCount == 0`。
actor TagMigrationCoordinator
{
    static let batchSize = 100

    private let service: TagServicing
    private let notificationCenter: NotificationCenter

    init(
        service: TagServicing,
        notificationCenter: NotificationCenter = .default
    )
    {
        self.service = service
        self.notificationCenter = notificationCenter
    }

    func resume() async throws
    {
        var result: TagMigrationBatchResult
        repeat
        {
            result = try await service.migrateNextBatch(limit: Self.batchSize)
            if result.migratedCount > 0
            {
                await MainActor.run
                {
                    notificationCenter.post(name: .clipTagsDidUpdate, object: nil)
                }
            }
        }
        while result.remainingCount > 0
    }
}
