@testable import ClipMind
import Foundation
import XCTest

// MARK: - Shared Helpers

/// Picker 测试共享的异步等待工具。
///
/// 复用 `TagPickerViewModelTests` 中的 `FakeTagService`，避免重复定义 test double。
enum TagPickerTestWaiter
{
    static func waitForReady(_ store: TagStore) async
    {
        await waitForAsync { await store.loadState == .ready }
    }

    static func waitForAsync(
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
}

// MARK: - TagPickerViewModel Candidate Tests

/// 候选标签、搜索、创建入口、上限和系统标签移除状态测试。
@MainActor
final class TagPickerViewModelCandidateTests: XCTestCase
{
    private var fake: FakeTagService!
    private var coordinator: TagMigrationCoordinator!
    private var store: TagStore!
    private var clipID: UUID!
    private let clipContentType: ContentType = .article

    override func setUp() async throws
    {
        try await super.setUp()
        fake = FakeTagService()
        coordinator = TagMigrationCoordinator(service: fake)
        store = TagStore(service: fake, migrationCoordinator: coordinator)
        clipID = UUID()
    }

    override func tearDown() async throws
    {
        store = nil
        coordinator = nil
        fake = nil
        clipID = nil
        try await super.tearDown()
    }

    func testCandidateTagsIncludesOwnSystemTagAndAllUserTags() async
    {
        let userTag1 = ClipTag(id: .user(), name: "Work", color: .blue, source: .user)
        let userTag2 = ClipTag(id: .user(), name: "Personal", color: .rose, source: .user)
        let snapshot = TagSnapshot(
            userTags: [userTag1, userTag2],
            tagStatesByClipID: [clipID: .newItem(contentType: clipContentType)]
        )
        await fake.setSnapshotResult(snapshot)
        store.load()
        await TagPickerTestWaiter.waitForReady(store)

        let viewModel = TagPickerViewModel(
            clipID: clipID,
            contentType: clipContentType,
            store: store
        )

        let candidateIDs = Set(viewModel.candidateTags.map(\.id))
        XCTAssertTrue(candidateIDs.contains(.system(clipContentType)), "应包含条目自身系统标签")
        XCTAssertTrue(candidateIDs.contains(userTag1.id), "应包含用户标签 1")
        XCTAssertTrue(candidateIDs.contains(userTag2.id), "应包含用户标签 2")
    }

    func testCandidateTagsExcludesOtherSystemTags() async
    {
        let snapshot = TagSnapshot(
            userTags: [],
            tagStatesByClipID: [clipID: .newItem(contentType: clipContentType)]
        )
        await fake.setSnapshotResult(snapshot)
        store.load()
        await TagPickerTestWaiter.waitForReady(store)

        let viewModel = TagPickerViewModel(
            clipID: clipID,
            contentType: clipContentType,
            store: store
        )

        let candidateIDs = Set(viewModel.candidateTags.map(\.id))
        let otherContentTypes = ContentType.allCases.filter { $0 != clipContentType }
        for other in otherContentTypes
        {
            XCTAssertFalse(
                candidateIDs.contains(.system(other)),
                "其他系统标签 \(other.rawValue) 不应出现在候选中"
            )
        }
    }

    func testSearchIsCaseInsensitiveAndSubstring() async
    {
        let userTag1 = ClipTag(id: .user(), name: "Work", color: .blue, source: .user)
        let userTag2 = ClipTag(id: .user(), name: "WORKPLACE", color: .rose, source: .user)
        let userTag3 = ClipTag(id: .user(), name: "Home", color: .amber, source: .user)
        let snapshot = TagSnapshot(
            userTags: [userTag1, userTag2, userTag3],
            tagStatesByClipID: [clipID: .newItem(contentType: clipContentType)]
        )
        await fake.setSnapshotResult(snapshot)
        store.load()
        await TagPickerTestWaiter.waitForReady(store)

        let viewModel = TagPickerViewModel(
            clipID: clipID,
            contentType: clipContentType,
            store: store
        )

        viewModel.searchText = "work"
        let filteredNames = viewModel.filteredTags.map(\.name)
        XCTAssertEqual(Set(filteredNames), ["Work", "WORKPLACE"], "大小写不敏感包含匹配")
        XCTAssertFalse(filteredNames.contains("Home"))
    }

    func testClearSearchRestoresAllCandidates() async
    {
        let userTag1 = ClipTag(id: .user(), name: "Work", color: .blue, source: .user)
        let userTag2 = ClipTag(id: .user(), name: "Home", color: .rose, source: .user)
        let snapshot = TagSnapshot(
            userTags: [userTag1, userTag2],
            tagStatesByClipID: [clipID: .newItem(contentType: clipContentType)]
        )
        await fake.setSnapshotResult(snapshot)
        store.load()
        await TagPickerTestWaiter.waitForReady(store)

        let viewModel = TagPickerViewModel(
            clipID: clipID,
            contentType: clipContentType,
            store: store
        )

        viewModel.searchText = "work"
        XCTAssertEqual(viewModel.filteredTags.count, 1)
        viewModel.searchText = ""
        XCTAssertEqual(
            Set(viewModel.filteredTags.map(\.id)),
            Set(viewModel.candidateTags.map(\.id)),
            "清空搜索应恢复全部候选"
        )
    }

    func testCreateEntryAppearsWhenNoMatchAndNameValid() async
    {
        let userTag = ClipTag(id: .user(), name: "Existing", color: .blue, source: .user)
        let snapshot = TagSnapshot(
            userTags: [userTag],
            tagStatesByClipID: [clipID: .newItem(contentType: clipContentType)]
        )
        await fake.setSnapshotResult(snapshot)
        store.load()
        await TagPickerTestWaiter.waitForReady(store)

        let viewModel = TagPickerViewModel(
            clipID: clipID,
            contentType: clipContentType,
            store: store
        )

        viewModel.searchText = "NewName"
        XCTAssertTrue(viewModel.filteredTags.isEmpty, "无匹配候选")
        XCTAssertTrue(viewModel.canCreate, "无匹配且名称有效时应可创建")
        XCTAssertEqual(viewModel.mode, .browse)
    }

    func testCanCreateIsFalseWhenNameMatchesExisting() async
    {
        let userTag = ClipTag(id: .user(), name: "Existing", color: .blue, source: .user)
        let snapshot = TagSnapshot(
            userTags: [userTag],
            tagStatesByClipID: [clipID: .newItem(contentType: clipContentType)]
        )
        await fake.setSnapshotResult(snapshot)
        store.load()
        await TagPickerTestWaiter.waitForReady(store)

        let viewModel = TagPickerViewModel(
            clipID: clipID,
            contentType: clipContentType,
            store: store
        )

        viewModel.searchText = "existing"
        XCTAssertFalse(viewModel.canCreate, "重名（大小写不敏感）不应允许创建")
    }

    func testAtLimitDisablesUnselectedAndCreateEntry() async
    {
        let userTag1 = ClipTag(id: .user(), name: "Tag1", color: .blue, source: .user)
        let userTag2 = ClipTag(id: .user(), name: "Tag2", color: .rose, source: .user)
        let userTag3 = ClipTag(id: .user(), name: "Tag3", color: .amber, source: .user)
        let userTag4 = ClipTag(id: .user(), name: "Tag4", color: .emerald, source: .user)
        let extraUser = ClipTag(id: .user(), name: "UnselectedTag", color: .purple, source: .user)
        let state = ClipTagState(
            orderedTagIDs: [
                .system(clipContentType),
                userTag1.id,
                userTag2.id,
                userTag3.id,
                userTag4.id
            ],
            systemTagDisposition: .associated,
            migrationVersion: ClipTagState.currentMigrationVersion
        )
        let snapshot = TagSnapshot(
            userTags: [userTag1, userTag2, userTag3, userTag4, extraUser],
            tagStatesByClipID: [clipID: state]
        )
        await fake.setSnapshotResult(snapshot)
        store.load()
        await TagPickerTestWaiter.waitForReady(store)

        let viewModel = TagPickerViewModel(
            clipID: clipID,
            contentType: clipContentType,
            store: store
        )

        XCTAssertTrue(viewModel.isAtLimit, "已 5 个标签应识别为上限")
        XCTAssertTrue(viewModel.isDisabled(extraUser), "未选标签在上限时应禁用")
        XCTAssertFalse(viewModel.isDisabled(userTag1), "已选标签在上限时仍可取消")
        XCTAssertFalse(viewModel.isDisabled(userTag2), "已选标签在上限时仍可取消")
        let systemTag = SystemTagCatalog.tag(for: clipContentType)
        XCTAssertFalse(viewModel.isDisabled(systemTag), "已选系统标签可被移除")
        XCTAssertFalse(viewModel.canCreate, "上限时不应允许创建")
    }

    func testRemovedSystemTagStillInCandidatesAndUnselected() async
    {
        let state = ClipTagState(
            orderedTagIDs: [],
            systemTagDisposition: .removed,
            migrationVersion: ClipTagState.currentMigrationVersion
        )
        let snapshot = TagSnapshot(
            userTags: [],
            tagStatesByClipID: [clipID: state]
        )
        await fake.setSnapshotResult(snapshot)
        store.load()
        await TagPickerTestWaiter.waitForReady(store)

        let viewModel = TagPickerViewModel(
            clipID: clipID,
            contentType: clipContentType,
            store: store
        )

        let systemTag = SystemTagCatalog.tag(for: clipContentType)
        XCTAssertTrue(
            viewModel.candidateTags.contains(where: { $0.id == systemTag.id }),
            "系统标签移除后仍应出现在候选中"
        )
        XCTAssertFalse(viewModel.isSelected(systemTag), "系统标签移除后应为未勾选")
    }
}

// MARK: - TagPickerViewModel Interaction Tests

/// 创建、toggle、error 与 retry 行为测试。
@MainActor
final class TagPickerViewModelInteractionTests: XCTestCase
{
    private var fake: FakeTagService!
    private var coordinator: TagMigrationCoordinator!
    private var store: TagStore!
    private var clipID: UUID!
    private let clipContentType: ContentType = .article

    override func setUp() async throws
    {
        try await super.setUp()
        fake = FakeTagService()
        coordinator = TagMigrationCoordinator(service: fake)
        store = TagStore(service: fake, migrationCoordinator: coordinator)
        clipID = UUID()
    }

    override func tearDown() async throws
    {
        store = nil
        coordinator = nil
        fake = nil
        clipID = nil
        try await super.tearDown()
    }

    func testConfirmCreateClearsSearchAndReturnsToBrowse() async
    {
        let initial = TagSnapshot(
            userTags: [],
            tagStatesByClipID: [clipID: .newItem(contentType: clipContentType)]
        )
        let createdTag = ClipTag(id: .user(), name: "NewTag", color: .violet, source: .user)
        let afterCreate = TagSnapshot(
            userTags: [createdTag],
            tagStatesByClipID: [clipID: .newItem(contentType: clipContentType)]
        )
        await fake.setSnapshotResult(initial)
        store.load()
        await TagPickerTestWaiter.waitForReady(store)

        await fake.setDefaultMutationResult(afterCreate)

        let viewModel = TagPickerViewModel(
            clipID: clipID,
            contentType: clipContentType,
            store: store
        )

        viewModel.searchText = "NewTag"
        viewModel.beginCreate()
        XCTAssertEqual(viewModel.mode, .create)
        viewModel.proposedName = "NewTag"
        viewModel.selectedColor = .violet
        viewModel.confirmCreate()

        await TagPickerTestWaiter.waitForAsync { self.store.snapshot == afterCreate }

        XCTAssertEqual(viewModel.mode, .browse, "创建成功应回到浏览模式")
        XCTAssertEqual(viewModel.searchText, "", "创建成功应清空搜索")
        XCTAssertEqual(viewModel.proposedName, "", "创建成功应清空名称")
    }

    func testErrorMessagePropagatedFromStore() async
    {
        let initial = TagSnapshot(
            userTags: [],
            tagStatesByClipID: [clipID: .newItem(contentType: clipContentType)]
        )
        await fake.setSnapshotResult(initial)
        store.load()
        await TagPickerTestWaiter.waitForReady(store)

        await fake.setDefaultMutationError(TagError.tagLimitReached)

        let viewModel = TagPickerViewModel(
            clipID: clipID,
            contentType: clipContentType,
            store: store
        )

        viewModel.beginCreate()
        viewModel.proposedName = "SomeName"
        viewModel.confirmCreate()

        await TagPickerTestWaiter.waitForAsync { self.store.errorMessage != nil }

        XCTAssertEqual(
            viewModel.errorMessage,
            TagError.tagLimitReached.errorDescription,
            "ViewModel 应暴露 store 的安全错误文案"
        )
    }

    func testRetryDelegatesToStoreRetry() async
    {
        let initial = TagSnapshot(
            userTags: [],
            tagStatesByClipID: [clipID: .newItem(contentType: clipContentType)]
        )
        let afterCreate = TagSnapshot(
            userTags: [ClipTag(id: .user(), name: "NewTag", color: .violet, source: .user)],
            tagStatesByClipID: [clipID: .newItem(contentType: clipContentType)]
        )
        await fake.setSnapshotResult(initial)
        store.load()
        await TagPickerTestWaiter.waitForReady(store)

        await fake.enqueueMutationOverride(.failure(TagError.tagLimitReached))
        await fake.enqueueMutationOverride(.success(afterCreate))

        let viewModel = TagPickerViewModel(
            clipID: clipID,
            contentType: clipContentType,
            store: store
        )

        viewModel.beginCreate()
        viewModel.proposedName = "NewTag"
        viewModel.confirmCreate()
        await TagPickerTestWaiter.waitForAsync { self.store.failedOperation != nil }

        viewModel.retry()
        await TagPickerTestWaiter.waitForAsync { self.store.snapshot == afterCreate }
        XCTAssertNil(store.failedOperation, "retry 应触发 store 重放并清除失败")
    }

    func testToggleQueuesSetAttachedOperation() async
    {
        let userTag = ClipTag(id: .user(), name: "Work", color: .blue, source: .user)
        let initial = TagSnapshot(
            userTags: [userTag],
            tagStatesByClipID: [clipID: .newItem(contentType: clipContentType)]
        )
        let afterAttach = TagSnapshot(
            userTags: [userTag],
            tagStatesByClipID: [
                clipID: ClipTagState(
                    orderedTagIDs: [.system(clipContentType), userTag.id],
                    systemTagDisposition: .associated,
                    migrationVersion: ClipTagState.currentMigrationVersion
                )
            ]
        )
        await fake.setSnapshotResult(initial)
        store.load()
        await TagPickerTestWaiter.waitForReady(store)

        await fake.setDefaultMutationResult(afterAttach)

        let viewModel = TagPickerViewModel(
            clipID: clipID,
            contentType: clipContentType,
            store: store
        )

        XCTAssertFalse(viewModel.isSelected(userTag))
        viewModel.toggle(userTag)
        await TagPickerTestWaiter.waitForAsync { self.store.snapshot == afterAttach }

        let calls = await fake.mutationCalls
        XCTAssertEqual(
            calls,
            [.setAttached(true, tagID: userTag.id, clipID: clipID)],
            "toggle 应入队 setAttached 操作"
        )
    }

    func testBeginAndCancelCreate() async
    {
        let snapshot = TagSnapshot(
            userTags: [],
            tagStatesByClipID: [clipID: .newItem(contentType: clipContentType)]
        )
        await fake.setSnapshotResult(snapshot)
        store.load()
        await TagPickerTestWaiter.waitForReady(store)

        let viewModel = TagPickerViewModel(
            clipID: clipID,
            contentType: clipContentType,
            store: store
        )

        XCTAssertEqual(viewModel.mode, .browse)
        viewModel.beginCreate()
        XCTAssertEqual(viewModel.mode, .create)
        viewModel.cancelCreate()
        XCTAssertEqual(viewModel.mode, .browse)
        XCTAssertEqual(viewModel.proposedName, "", "取消创建应清空名称")
    }
}
