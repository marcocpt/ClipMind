import Foundation

// MARK: - 标签后端

/// 生产标签后端：持有唯一 `TagServicing` 和迁移协调器。
struct TagBackend
{
    let service: TagServicing
    let migrationCoordinator: TagMigrationCoordinator
}

// MARK: - 工厂

enum TagBackendFactory
{
    /// 创建默认标签后端。
    ///
    /// 初始化失败时返回 `UnavailableTagService`，不创建第二个空数据库。
    static func makeDefault() -> TagBackend
    {
        let store: EncryptedStore
        do
        {
            store = try EncryptedStore()
        } catch {
            LogCategory.storage.error(
                "TagBackend EncryptedStore init failed: \(error.localizedDescription)"
            )
            let unavailableService = UnavailableTagService()
            let unavailableCoordinator = TagMigrationCoordinator(
                service: unavailableService
            )
            return TagBackend(
                service: unavailableService,
                migrationCoordinator: unavailableCoordinator
            )
        }

        let logger = DefaultTagOperationLogger()
        let service = TagService(repository: store, logger: logger)
        let coordinator = TagMigrationCoordinator(service: service)
        return TagBackend(
            service: service,
            migrationCoordinator: coordinator
        )
    }
}
