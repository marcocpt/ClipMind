import Foundation

/// 标签 UI 状态管理器。
///
/// 维护三个互不取消的通道：load（读取快照）、mutation drain（串行执行标签变更）、
/// migration（旧数据迁移）。mutation 一旦被 `perform(_:)` 接受，不会因后续 load 或
/// View 消失而取消；load 与 migration 在 `deinit` 时才会被取消。
///
/// 错误映射为 `TagError.errorDescription` 固定安全文案，不向日志或 UI 暴露标签名、
/// Task 对象或底层 localizedDescription。
@MainActor
final class TagStore: ObservableObject
{
    /// 加载状态。
    enum LoadState: Equatable
    {
        case loading
        case ready
        case unavailable
    }

    /// 标签变更操作。结构化捕获，便于失败后原样重放。
    enum MutationOperation: Equatable
    {
        case create(name: String, color: ClipTagColor, clipID: UUID)
        case setAttached(Bool, tagID: ClipTagID, clipID: UUID)
        case rename(tagID: ClipTagID, name: String)
        case delete(tagID: ClipTagID)
    }

    /// 失败的操作类型。retry 据此选择重放路径。
    enum FailedOperation: Equatable
    {
        case mutation(MutationOperation)
        case migration
    }

    @Published private(set) var snapshot: TagSnapshot = .empty
    @Published private(set) var loadState = LoadState.loading
    @Published private(set) var isSaving = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var failedOperation: FailedOperation?

    private let service: TagServicing
    private let migrationCoordinator: TagMigrationCoordinator
    private var loadTask: Task<Void, Never>?
    private var loadGeneration = 0
    private var mutationTask: Task<Void, Never>?
    private var pendingOperations: [MutationOperation] = []
    private var migrationTask: Task<Void, Never>?
    /// mutation 排空期间出现更新的 load 请求时，标记需要在 drain 结束后补一次 load。
    private var needsLoadAfterDrain = false
    private var observers: [NSObjectProtocol] = []

    /// 构造 TagStore。
    /// - Parameters:
    ///   - service: 标签服务端口，提供快照与 mutation 能力。
    ///   - migrationCoordinator: 旧数据迁移协调器，独立于 service 通道运行。
    init(service: TagServicing, migrationCoordinator: TagMigrationCoordinator)
    {
        self.service = service
        self.migrationCoordinator = migrationCoordinator
        registerNotificationObservers()
    }

    deinit
    {
        for observer in observers
        {
            NotificationCenter.default.removeObserver(observer)
        }
        loadTask?.cancel()
        migrationTask?.cancel()
    }

    /// 返回指定条目当前关联的标签列表。
    /// - Parameter clipID: 条目 ID。
    /// - Returns: 当前快照下该条目的标签数组。
    func tags(for clipID: UUID) -> [ClipTag]
    {
        snapshot.tags(for: clipID)
    }

    /// 触发一次快照读取。
    ///
    /// 取消上一个 `loadTask` 并递增 generation；只在仍为最新且 mutation 未在执行时
    /// 发布结果，否则在 mutation 排空后再补一次 load。捕获 `CancellationError`
    /// 不更新状态。
    func load()
    {
        loadGeneration += 1
        let generation = loadGeneration
        loadTask?.cancel()

        loadTask = Task { [weak self] in
            guard let self = self else { return }
            do
            {
                let loaded = try await self.service.snapshot()
                guard self.loadGeneration == generation else { return }
                if self.mutationTask != nil
                {
                    self.needsLoadAfterDrain = true
                    return
                }
                self.snapshot = loaded
                self.loadState = .ready
            } catch is CancellationError {
                // 取消不视为错误，保留当前状态。
            } catch {
                guard self.loadGeneration == generation else { return }
                self.loadState = .unavailable
                self.logFailure(scope: "load", error: error)
            }
        }
    }

    /// 接受一个标签变更操作并排入串行队列。
    ///
    /// 已接受的 operation 不会因后续 load 或 View 消失而取消。
    /// 若当前无 drain 在执行，立即启动 `drainMutationQueue()`。
    /// - Parameter operation: 结构化变更操作。
    func perform(_ operation: MutationOperation)
    {
        pendingOperations.append(operation)
        if mutationTask == nil
        {
            drainMutationQueue()
        }
    }

    /// 重放失败的操作并恢复对应通道。
    ///
    /// - 若失败为 `.mutation`，重置错误状态并重启 drain；失败项已在队首。
    /// - 若失败为 `.migration`，重新调用 `resumeMigration()`。
    func retry()
    {
        switch failedOperation
        {
        case .mutation:
            errorMessage = nil
            failedOperation = nil
            if mutationTask == nil
            {
                drainMutationQueue()
            }
        case .migration:
            errorMessage = nil
            failedOperation = nil
            resumeMigration()
        case .none:
            break
        }
    }

    /// 启动或继续迁移通道。
    ///
    /// 单一独立 `migrationTask` 调 `coordinator.resume()`；成功后再 `load()`，
    /// 失败记录 `.migration`。批次通知只触发 `load()`，不会取消本 task。
    func resumeMigration()
    {
        migrationTask?.cancel()
        migrationTask = Task { [weak self] in
            guard let self = self else { return }
            do
            {
                try await self.migrationCoordinator.resume()
                self.load()
            } catch is CancellationError {
                // 取消不视为错误。
            } catch {
                self.failedOperation = .migration
                self.errorMessage = Self.safeErrorMessage(for: error)
                self.logFailure(scope: "migration", error: error)
            }
            self.migrationTask = nil
        }
    }

    // MARK: - Mutation Drain

    /// 串行排空 `pendingOperations`。
    ///
    /// 单一 `mutationTask` FIFO 执行；每项用 exhaustive switch 调 `TagServicing`，
    /// 成功发布 service 返回的 snapshot；失败保留最近成功快照、记录 `.mutation(operation)`
    /// 并暂停，不吞掉排在其后的意图。
    private func drainMutationQueue()
    {
        isSaving = true
        mutationTask = Task { [weak self] in
            guard let self = self else { return }
            let drained = await self.processPendingOperations()
            self.mutationTask = nil
            self.isSaving = false
            if drained && self.needsLoadAfterDrain
            {
                self.needsLoadAfterDrain = false
                self.load()
            }
        }
    }

    /// 处理队列中所有操作，直到排空或遇到失败。
    /// - Returns: `true` 表示全部排空；`false` 表示因失败或取消暂停。
    private func processPendingOperations() async -> Bool
    {
        while !pendingOperations.isEmpty
        {
            guard let operation = pendingOperations.first else { break }
            do
            {
                let next = try await executeMutation(operation)
                pendingOperations.removeFirst()
                snapshot = next
                errorMessage = nil
                failedOperation = nil
            } catch is CancellationError {
                // mutation 不应被外部取消；此处保留操作在队首，等待下次 drain。
                return false
            } catch {
                failedOperation = .mutation(operation)
                errorMessage = Self.safeErrorMessage(for: error)
                logFailure(scope: "mutation", error: error)
                return false
            }
        }
        return true
    }

    /// 用 exhaustive switch 把 `MutationOperation` 映射到 `TagServicing` 调用。
    private func executeMutation(_ operation: MutationOperation) async throws -> TagSnapshot
    {
        switch operation
        {
        case let .create(name, color, clipID):
            return try await service.createAndAttach(name: name, color: color, clipID: clipID)
        case let .setAttached(isAttached, tagID, clipID):
            return try await service.setAttached(isAttached, tagID: tagID, clipID: clipID)
        case let .rename(tagID, name):
            return try await service.renameUserTag(id: tagID, name: name)
        case let .delete(tagID):
            return try await service.deleteUserTag(id: tagID)
        }
    }

    // MARK: - Notifications

    /// 监听 ClipCaptureService.clipDidUpdateNotification 与 .clipTagsDidUpdate；
    /// 收到任一通知都取消旧 load 并重新读取快照。不携带内容或标签名。
    private func registerNotificationObservers()
    {
        let center = NotificationCenter.default
        observers.append(
            center.addObserver(
                forName: ClipCaptureService.clipDidUpdateNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.load()
                }
            }
        )
        observers.append(
            center.addObserver(
                forName: .clipTagsDidUpdate,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.load()
                }
            }
        )
    }

    // MARK: - Error Mapping

    /// 把任意错误映射为固定安全文案。
    /// `TagError` 直接取 `errorDescription`；其他错误使用 `persistenceFailed` 文案。
    private static func safeErrorMessage(for error: Error) -> String
    {
        if let tagError = error as? TagError
        {
            return tagError.errorDescription ?? TagError.persistenceFailed.errorDescription!
        } else {
            return TagError.persistenceFailed.errorDescription!
        }
    }

    /// 记录失败日志，仅写闭集 scope 与错误码，不写 Task、标签名或 localizedDescription。
    private func logFailure(scope: String, error: Error)
    {
        let errorCode: String
        if let tagError = error as? TagError
        {
            errorCode = tagError.rawValue
        } else {
            errorCode = "unknown"
        }
        LogCategory.ui.error("tag store failure scope=\(scope) error=\(errorCode)")
    }
}
