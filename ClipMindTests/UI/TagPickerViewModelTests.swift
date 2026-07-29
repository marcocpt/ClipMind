@testable import ClipMind
import Foundation
import XCTest

// MARK: - FakeTagService

/// 用于 TagStore 测试的 `TagServicing` fake。
///
/// 以 actor 实现，确保 coordinator（独立 actor）与 @MainActor 测试之间的调用安全。
/// 支持按调用覆盖返回值、挂起下一次调用以控制时序，以及追踪全部 mutation 调用。
actor FakeTagService: TagServicing
{
    private var snapshotResult: TagSnapshot = .empty
    private var snapshotError: Error?
    private var defaultMutationResult: TagSnapshot = .empty
    private var defaultMutationError: Error?
    private var snapshotOverrides: [Result<TagSnapshot, Error>] = []
    private var mutationOverrides: [Result<TagSnapshot, Error>] = []
    private var migrationBatches: [TagMigrationBatchResult] = []
    private var migrationError: Error?
    private var suspendNextSnapshots = 0
    private var suspendNextMutations = 0
    private var suspendedSnapshots: [CheckedContinuation<Void, Never>] = []
    private var suspendedMutations: [CheckedContinuation<Void, Never>] = []
    private(set) var snapshotCallCount = 0
    private(set) var mutationCalls: [TagStore.MutationOperation] = []
    private(set) var migrateCallCount = 0

    // MARK: Configuration

    func setSnapshotResult(_ result: TagSnapshot) { snapshotResult = result }
    func setSnapshotError(_ error: Error?) { snapshotError = error }
    func setDefaultMutationResult(_ result: TagSnapshot) { defaultMutationResult = result }
    func setDefaultMutationError(_ error: Error?) { defaultMutationError = error }
    func setMigrationError(_ error: Error?) { migrationError = error }
    func enqueueSnapshotOverride(_ result: Result<TagSnapshot, Error>) { snapshotOverrides.append(result) }
    func enqueueMutationOverride(_ result: Result<TagSnapshot, Error>) { mutationOverrides.append(result) }
    func setMigrationBatches(_ batches: [TagMigrationBatchResult]) { migrationBatches = batches }
    func setSuspendNextSnapshots(_ count: Int) { suspendNextSnapshots = count }
    func setSuspendNextMutations(_ count: Int) { suspendNextMutations = count }

    func resumeAllSnapshots()
    {
        for cont in suspendedSnapshots { cont.resume() }
        suspendedSnapshots.removeAll()
    }

    func resumeAllMutations()
    {
        for cont in suspendedMutations { cont.resume() }
        suspendedMutations.removeAll()
    }

    // MARK: TagServicing

    func snapshot() async throws -> TagSnapshot
    {
        snapshotCallCount += 1
        let result: Result<TagSnapshot, Error>
        if !snapshotOverrides.isEmpty
        {
            result = snapshotOverrides.removeFirst()
        } else if let error = snapshotError {
            result = .failure(error)
        } else {
            result = .success(snapshotResult)
        }
        if suspendNextSnapshots > 0
        {
            suspendNextSnapshots -= 1
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                suspendedSnapshots.append(cont)
            }
        }
        return try result.get()
    }

    private func nextMutationResult() async throws -> TagSnapshot
    {
        if suspendNextMutations > 0
        {
            suspendNextMutations -= 1
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                suspendedMutations.append(cont)
            }
        }
        if !mutationOverrides.isEmpty
        {
            return try mutationOverrides.removeFirst().get()
        }
        if let error = defaultMutationError { throw error }
        return defaultMutationResult
    }

    func createAndAttach(name: String, color: ClipTagColor, clipID: UUID) async throws -> TagSnapshot
    {
        mutationCalls.append(.create(name: name, color: color, clipID: clipID))
        return try await nextMutationResult()
    }

    func setAttached(_ isAttached: Bool, tagID: ClipTagID, clipID: UUID) async throws -> TagSnapshot
    {
        mutationCalls.append(.setAttached(isAttached, tagID: tagID, clipID: clipID))
        return try await nextMutationResult()
    }

    func renameUserTag(id: ClipTagID, name: String) async throws -> TagSnapshot
    {
        mutationCalls.append(.rename(tagID: id, name: name))
        return try await nextMutationResult()
    }

    func deleteUserTag(id: ClipTagID) async throws -> TagSnapshot
    {
        mutationCalls.append(.delete(tagID: id))
        return try await nextMutationResult()
    }

    func migrateNextBatch(limit: Int) async throws -> TagMigrationBatchResult
    {
        migrateCallCount += 1
        if let error = migrationError { throw error }
        if migrationBatches.isEmpty
        {
            return TagMigrationBatchResult(migratedCount: 0, remainingCount: 0)
        }
        return migrationBatches.removeFirst()
    }
}

// MARK: - TagStore Tests

@MainActor
final class TagPickerViewModelTests: XCTestCase
{
    private var fake: FakeTagService!
    private var coordinator: TagMigrationCoordinator!
    private var store: TagStore!

    override func setUp() async throws
    {
        try await super.setUp()
        fake = FakeTagService()
        coordinator = TagMigrationCoordinator(service: fake)
        store = TagStore(service: fake, migrationCoordinator: coordinator)
    }

    override func tearDown() async throws
    {
        store = nil
        coordinator = nil
        fake = nil
        try await super.tearDown()
    }

    // MARK: - Load State

    func testInitialStateIsLoading()
    {
        XCTAssertEqual(store.loadState, .loading)
        XCTAssertEqual(store.snapshot, .empty)
        XCTAssertNil(store.errorMessage)
        XCTAssertNil(store.failedOperation)
        XCTAssertFalse(store.isSaving)
    }

    func testLoadPublishesSnapshotAndSetsReady() async
    {
        let snapshot = makeSnapshot(tagName: "Work")
        await fake.setSnapshotResult(snapshot)
        store.load()
        await waitForAsync { self.store.loadState == .ready }
        XCTAssertEqual(store.snapshot, snapshot)
    }

    func testLoadFailureSetsUnavailable() async
    {
        await fake.setSnapshotError(TagError.persistenceFailed)
        store.load()
        await waitForAsync { self.store.loadState == .unavailable }
        XCTAssertEqual(store.snapshot, .empty)
    }

    // MARK: - Generation Guard

    func testOlderLoadDoesNotOverwriteNewerGenerationSnapshot() async
    {
        let clipID = UUID()
        let snapshotA = makeSnapshot(tagName: "Alpha", clipID: clipID)
        let snapshotB = makeSnapshot(tagName: "Bravo", clipID: clipID)

        await fake.enqueueSnapshotOverride(.success(snapshotA))
        await fake.setSnapshotResult(snapshotB)
        await fake.setSuspendNextSnapshots(1)

        store.load()
        await waitForAsync { await self.fake.snapshotCallCount >= 1 }

        store.load()
        await waitForAsync { self.store.loadState == .ready }
        XCTAssertEqual(store.snapshot, snapshotB)

        await fake.resumeAllSnapshots()
        await yieldTimes(5)

        XCTAssertEqual(store.snapshot, snapshotB, "较旧 load 返回后不得覆盖更新 generation 的 snapshot")
    }

    // MARK: - Mutation FIFO

    func testRapidCreateAndToggleExecuteInOrder() async
    {
        let clipID = UUID()
        let tagID = ClipTagID.user()
        let afterCreate = makeSnapshot(tagName: "NewTag", clipID: clipID)
        let afterAttach = makeSnapshot(tagName: "NewTag", clipID: clipID, extraTagID: tagID)
        let afterDetach = makeSnapshot(tagName: "NewTag", clipID: clipID)

        await fake.enqueueMutationOverride(.success(afterCreate))
        await fake.enqueueMutationOverride(.success(afterAttach))
        await fake.enqueueMutationOverride(.success(afterDetach))

        store.perform(.create(name: "NewTag", color: .blue, clipID: clipID))
        store.perform(.setAttached(true, tagID: tagID, clipID: clipID))
        store.perform(.setAttached(false, tagID: tagID, clipID: clipID))

        await waitForAsync { self.store.snapshot == afterDetach }

        let calls = await fake.mutationCalls
        XCTAssertEqual(calls.count, 3)
        XCTAssertEqual(calls[0], .create(name: "NewTag", color: .blue, clipID: clipID))
        XCTAssertEqual(calls[1], .setAttached(true, tagID: tagID, clipID: clipID))
        XCTAssertEqual(calls[2], .setAttached(false, tagID: tagID, clipID: clipID))
        XCTAssertFalse(store.isSaving)
    }

    // MARK: - No Optimistic Mutation

    func testMutationPublishesOnlyAfterServiceReturns() async
    {
        let clipID = UUID()
        let initial = makeSnapshot(tagName: "Existing", clipID: clipID)
        let afterCreate = makeSnapshot(tagName: "NewTag", clipID: clipID, extraTagID: ClipTagID.user())

        await fake.setSnapshotResult(initial)
        store.load()
        await waitForAsync { self.store.loadState == .ready }

        await fake.setSuspendNextMutations(1)
        await fake.setDefaultMutationResult(afterCreate)

        store.perform(.create(name: "NewTag", color: .blue, clipID: clipID))
        await waitForAsync { await self.fake.mutationCalls.count >= 1 }

        XCTAssertEqual(store.snapshot, initial, "service 返回前不得 optimistic 发布")
        XCTAssertTrue(store.isSaving)

        await fake.resumeAllMutations()
        await waitForAsync { self.store.snapshot == afterCreate }
        XCTAssertFalse(store.isSaving)
    }

    // MARK: - Failure Keeps Snapshot

    func testMutationFailureKeepsSnapshotAndPausesQueue() async
    {
        let clipID = UUID()
        let tagID = ClipTagID.user()
        let initial = makeSnapshot(tagName: "Keep", clipID: clipID)
        let afterRename = makeSnapshot(tagName: "Renamed", clipID: clipID, extraTagID: tagID)

        await fake.setSnapshotResult(initial)
        store.load()
        await waitForAsync { self.store.loadState == .ready }

        await fake.enqueueMutationOverride(.failure(TagError.tagLimitReached))
        await fake.enqueueMutationOverride(.success(afterRename))

        store.perform(.rename(tagID: tagID, name: "Renamed"))
        store.perform(.rename(tagID: tagID, name: "Later"))

        await waitForAsync { self.store.failedOperation != nil }

        XCTAssertEqual(store.snapshot, initial, "失败后保持最近成功快照")
        XCTAssertEqual(store.failedOperation, .mutation(.rename(tagID: tagID, name: "Renamed")))

        let calls = await fake.mutationCalls
        XCTAssertEqual(calls.count, 1, "队列停止在失败项，后续不执行")
    }

    // MARK: - Error Message Safety

    func testErrorMessageEqualsTagErrorDescriptionWithoutTagName() async
    {
        let clipID = UUID()
        let tagName = "SecretTagName"
        let initial = makeSnapshot(tagName: "Keep", clipID: clipID)

        await fake.setSnapshotResult(initial)
        store.load()
        await waitForAsync { self.store.loadState == .ready }

        await fake.enqueueMutationOverride(.failure(TagError.tagLimitReached))
        store.perform(.create(name: tagName, color: .blue, clipID: clipID))

        await waitForAsync { self.store.errorMessage != nil }
        XCTAssertEqual(store.errorMessage, TagError.tagLimitReached.errorDescription)
        XCTAssertFalse(store.errorMessage?.contains(tagName) ?? true, "错误文案不得包含标签名")
    }

    // MARK: - Retry

    func testRetryReplaysFailedMutationAndContinuesQueue() async
    {
        let clipID = UUID()
        let tagID = ClipTagID.user()
        let initial = makeSnapshot(tagName: "Keep", clipID: clipID)
        let afterFirst = makeSnapshot(tagName: "First", clipID: clipID, extraTagID: tagID)
        let afterSecond = makeSnapshot(tagName: "Second", clipID: clipID, extraTagID: tagID)

        await fake.setSnapshotResult(initial)
        store.load()
        await waitForAsync { self.store.loadState == .ready }

        await fake.enqueueMutationOverride(.failure(TagError.tagLimitReached))
        await fake.enqueueMutationOverride(.success(afterFirst))
        await fake.enqueueMutationOverride(.success(afterSecond))

        store.perform(.rename(tagID: tagID, name: "First"))
        store.perform(.rename(tagID: tagID, name: "Second"))
        await waitForAsync { self.store.failedOperation != nil }
        XCTAssertEqual(store.snapshot, initial)

        store.retry()
        await waitForAsync { self.store.snapshot == afterSecond }

        XCTAssertEqual(store.snapshot, afterSecond, "retry 成功后继续后续队列")
        XCTAssertNil(store.failedOperation)
        XCTAssertNil(store.errorMessage)

        let calls = await fake.mutationCalls
        XCTAssertEqual(calls.count, 3, "失败重放 + 后续 = 3 次调用")
        XCTAssertEqual(calls[1], .rename(tagID: tagID, name: "First"), "retry 重放同一失败 operation")
        XCTAssertEqual(calls[2], .rename(tagID: tagID, name: "Second"))
    }

    // MARK: - Migration Channel

    func testMigrationBatchesDoNotCancelMigrationTask() async
    {
        let clipID = UUID()
        let migrated = makeSnapshot(tagName: "Migrated", clipID: clipID)

        await fake.setSnapshotResult(migrated)
        await fake.setMigrationBatches([
            TagMigrationBatchResult(migratedCount: 3, remainingCount: 2),
            TagMigrationBatchResult(migratedCount: 2, remainingCount: 0)
        ])

        store.resumeMigration()
        await waitForAsync { await self.fake.migrateCallCount >= 2 }
        await waitForAsync { self.store.loadState == .ready }

        XCTAssertNil(store.failedOperation, "迁移期间的通知不得取消 migration task")
        XCTAssertNotEqual(store.failedOperation, .migration)
        XCTAssertEqual(store.loadState, .ready)
        XCTAssertEqual(store.snapshot, migrated)
        let migrateCount = await fake.migrateCallCount
        XCTAssertEqual(migrateCount, 2, "两批迁移都执行")
    }

    func testMigrationFailureSetsFailedOperation() async
    {
        await fake.setMigrationError(TagError.persistenceFailed)
        store.resumeMigration()
        await waitForAsync { self.store.failedOperation == .migration }
        XCTAssertEqual(store.failedOperation, .migration)
        XCTAssertEqual(store.errorMessage, TagError.persistenceFailed.errorDescription)
    }

    // MARK: - Accepted Mutation Not Cancelled

    func testAcceptedMutationNotCancelledByLoadNotification() async
    {
        let clipID = UUID()
        let initial = makeSnapshot(tagName: "Initial", clipID: clipID)
        let afterCreate = makeSnapshot(tagName: "Created", clipID: clipID, extraTagID: ClipTagID.user())

        await fake.setSnapshotResult(initial)
        store.load()
        await waitForAsync { self.store.loadState == .ready }

        await fake.setSuspendNextMutations(1)
        await fake.setDefaultMutationResult(afterCreate)

        store.perform(.create(name: "Created", color: .blue, clipID: clipID))
        await waitForAsync { await self.fake.mutationCalls.count >= 1 }
        XCTAssertTrue(store.isSaving, "mutation 已被接受")

        NotificationCenter.default.post(name: .clipTagsDidUpdate, object: nil)
        await yieldTimes(3)
        XCTAssertTrue(store.isSaving, "load 通知不得取消已接受的 mutation")

        // mutation 成功后 service.snapshot 应返回最新状态；更新 fake 模拟此行为。
        await fake.setSnapshotResult(afterCreate)
        await fake.resumeAllMutations()
        await waitForAsync { self.store.snapshot == afterCreate }
        XCTAssertFalse(store.isSaving)
    }

    // MARK: - tags(for:)

    func testTagsForClipIDReturnsCurrentSnapshotTags() async
    {
        let clipID = UUID()
        let snapshot = TagSnapshot(
            userTags: [],
            tagStatesByClipID: [clipID: .newItem(contentType: .code)]
        )
        await fake.setSnapshotResult(snapshot)
        store.load()
        await waitForAsync { self.store.loadState == .ready }

        let tags = store.tags(for: clipID)
        XCTAssertEqual(tags.count, 1)
        XCTAssertEqual(tags.first?.id, .system(.code))
    }

    // MARK: - Helpers

    private func makeSnapshot(tagName: String, clipID: UUID = UUID(), extraTagID: ClipTagID? = nil) -> TagSnapshot
    {
        var userTags: [ClipTag] = [ClipTag(id: .user(), name: tagName, color: .blue, source: .user)]
        if let extraTagID = extraTagID
        {
            userTags.append(ClipTag(id: extraTagID, name: tagName, color: .blue, source: .user))
        }
        return TagSnapshot(
            userTags: userTags,
            tagStatesByClipID: [clipID: .newItem(contentType: .article)]
        )
    }

    private func waitForAsync(
        _ condition: @escaping () async -> Bool,
        timeout: TimeInterval = 5.0,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async
    {
        let deadline = Date().addingTimeInterval(timeout)
        while !(await condition()) && Date() < deadline
        {
            await Task.yield()
            try? await Task.sleep(nanoseconds: 1_000_000)
        }
        if !(await condition())
        {
            XCTFail("waitForAsync 超时（\(timeout)s）", file: file, line: line)
        }
    }

    private func yieldTimes(_ count: Int) async
    {
        for _ in 0..<count
        {
            await Task.yield()
            try? await Task.sleep(nanoseconds: 500_000)
        }
    }
}
