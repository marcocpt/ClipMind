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
    /// `CLIPMIND_DEV` 构建中，当 `--UITEST_TAG_FAIL_ONCE` 存在时包装 repository；
    /// 当 `--UITEST_TAG_FIXTURE` / `--UITEST_TAG_LIMIT_FIXTURE` 存在时注入夹具数据。
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

        #if CLIPMIND_DEV
        // 先通过原始 store 注入夹具，再包装 FailOnce decorator。
        // 若先包装再注入，FailOnce 会拦截 seeding 的第一个 createAndAttach，
        // 导致 fixture 标签（如「工作」pill）不存在，UI 测试无法启动。
        TagUITestSupport.seedFixturesIfNeeded(store: store, repository: store)
        let repository: TagRepository = TagUITestSupport.wrapRepositoryIfNeeded(store)
        #else
        let repository: TagRepository = store
        #endif

        let logger = DefaultTagOperationLogger()
        let service = TagService(repository: repository, logger: logger)
        let coordinator = TagMigrationCoordinator(service: service)
        return TagBackend(
            service: service,
            migrationCoordinator: coordinator
        )
    }
}
