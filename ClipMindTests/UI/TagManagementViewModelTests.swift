@testable import ClipMind
import Foundation
import XCTest

// MARK: - TagManagementViewModelTests

/// F1.14 Phase 4 任务 1：设置管理状态机测试。
///
/// 复用 `TagPickerViewModelTests.swift` 中定义的 `FakeTagService` actor，不重复 fake 实现。
/// 测试覆盖：
/// 1. 系统标签不进入可编辑集合；
/// 2. 用户标签点击重命名进入 `.editing`；
/// 3. 提交有效新名只进入 `.confirmRename`，尚未调用 service；
/// 4. 取消编辑或取消确认恢复 `.idle`，未发生 mutation；
/// 5. 空白/大小写重名在进入确认前拒绝；
/// 6. 删除先进入 `.confirmDelete`，确认后才调用 service；
/// 7. service 失败回到 `.idle` 并由 `TagStore` 保持原快照；
/// 8. service 成功后所有消费者按同一 tag ID 显示新名。
@MainActor
final class TagManagementViewModelTests: XCTestCase
{
    private var fake: FakeTagService!
    private var coordinator: TagMigrationCoordinator!
    private var store: TagStore!
    private var viewModel: TagManagementViewModel!

    override func setUp() async throws
    {
        try await super.setUp()
        fake = FakeTagService()
        coordinator = TagMigrationCoordinator(service: fake)
        store = TagStore(service: fake, migrationCoordinator: coordinator)
        viewModel = TagManagementViewModel(store: store)
    }

    override func tearDown() async throws
    {
        viewModel = nil
        store = nil
        coordinator = nil
        fake = nil
        try await super.tearDown()
    }

    // MARK: - TC-TM-01：系统标签不进入可编辑集合

    func testBeginRenameOnSystemTagStaysIdle() async
    {
        await seedSnapshot(userTags: [])
        let systemTag = SystemTagCatalog.all.first!

        viewModel.beginRename(systemTag)

        XCTAssertEqual(viewModel.state, .idle, "系统标签不得进入 editing 状态")
        XCTAssertEqual(viewModel.draftName, "", "draftName 不应被修改")
    }

    // MARK: - TC-TM-02：用户标签点击重命名进入 .editing

    func testBeginRenameOnUserTagEntersEditing() async
    {
        let tagID = ClipTagID.user()
        let tag = ClipTag(id: tagID, name: "Work", color: .blue, source: .user)
        await seedSnapshot(userTags: [tag])

        viewModel.beginRename(tag)

        XCTAssertEqual(viewModel.state, .editing(tagID: tagID))
        XCTAssertEqual(viewModel.draftName, "Work", "draftName 应初始化为当前标签名")
        XCTAssertNil(viewModel.validationMessage)
    }

    // MARK: - TC-TM-03：提交有效新名只进入 .confirmRename，尚未调用 service

    func testSubmitRenameValidNameEntersConfirmWithoutServiceCall() async
    {
        let tagID = ClipTagID.user()
        let tag = ClipTag(id: tagID, name: "Work", color: .blue, source: .user)
        await seedSnapshot(userTags: [tag])

        viewModel.beginRename(tag)
        viewModel.draftName = "WorkRenamed"
        viewModel.submitRename()

        XCTAssertEqual(
            viewModel.state,
            .confirmRename(tagID: tagID, oldName: "Work", newName: "WorkRenamed")
        )
        let calls = await fake.mutationCalls
        XCTAssertTrue(calls.isEmpty, "submitRename 不应直接调用 service")
        XCTAssertNil(viewModel.validationMessage)
    }

    // MARK: - TC-TM-04：取消编辑或取消确认恢复 .idle，未发生 mutation

    func testCancelRenameFromEditingRestoresIdle() async
    {
        let tagID = ClipTagID.user()
        let tag = ClipTag(id: tagID, name: "Work", color: .blue, source: .user)
        await seedSnapshot(userTags: [tag])

        viewModel.beginRename(tag)
        viewModel.cancelRename()

        XCTAssertEqual(viewModel.state, .idle)
        let calls = await fake.mutationCalls
        XCTAssertTrue(calls.isEmpty)
    }

    func testCancelRenameFromConfirmRestoresIdleWithoutMutation() async
    {
        let tagID = ClipTagID.user()
        let tag = ClipTag(id: tagID, name: "Work", color: .blue, source: .user)
        await seedSnapshot(userTags: [tag])

        viewModel.beginRename(tag)
        viewModel.draftName = "WorkRenamed"
        viewModel.submitRename()
        viewModel.cancelRename()

        XCTAssertEqual(viewModel.state, .idle)
        let calls = await fake.mutationCalls
        XCTAssertTrue(calls.isEmpty, "取消确认不得调用 service")
    }

    // MARK: - TC-TM-05：空白/大小写重名在进入确认前拒绝

    func testSubmitRenameEmptyNameRejectsWithoutEnteringConfirm() async
    {
        let tagID = ClipTagID.user()
        let tag = ClipTag(id: tagID, name: "Work", color: .blue, source: .user)
        await seedSnapshot(userTags: [tag])

        viewModel.beginRename(tag)
        viewModel.draftName = "   "
        viewModel.submitRename()

        XCTAssertEqual(viewModel.state, .editing(tagID: tagID), "空白名称应停留在 editing")
        XCTAssertNotNil(viewModel.validationMessage, "应设置校验错误信息")
        let calls = await fake.mutationCalls
        XCTAssertTrue(calls.isEmpty)
    }

    func testSubmitRenameCaseInsensitiveDuplicateRejectsWithoutEnteringConfirm() async
    {
        let tagID = ClipTagID.user()
        let otherID = ClipTagID.user()
        let tag = ClipTag(id: tagID, name: "Work", color: .blue, source: .user)
        let other = ClipTag(id: otherID, name: "Existing", color: .amber, source: .user)
        await seedSnapshot(userTags: [tag, other])

        viewModel.beginRename(tag)
        viewModel.draftName = "EXISTING"
        viewModel.submitRename()

        XCTAssertEqual(viewModel.state, .editing(tagID: tagID), "重名应停留在 editing")
        XCTAssertNotNil(viewModel.validationMessage)
        let calls = await fake.mutationCalls
        XCTAssertTrue(calls.isEmpty)
    }

    // MARK: - TC-TM-06：删除先进入 .confirmDelete，确认后才调用 service

    func testBeginDeleteOnUserTagEntersConfirmDeleteWithoutServiceCall() async
    {
        let tagID = ClipTagID.user()
        let tag = ClipTag(id: tagID, name: "Work", color: .blue, source: .user)
        await seedSnapshot(userTags: [tag])

        viewModel.beginDelete(tag)

        XCTAssertEqual(viewModel.state, .confirmDelete(tagID: tagID, name: "Work"))
        let calls = await fake.mutationCalls
        XCTAssertTrue(calls.isEmpty, "beginDelete 不应直接调用 service")
    }

    func testBeginDeleteOnSystemTagStaysIdle() async
    {
        await seedSnapshot(userTags: [])
        let systemTag = SystemTagCatalog.all.first!

        viewModel.beginDelete(systemTag)

        XCTAssertEqual(viewModel.state, .idle, "系统标签不得进入 confirmDelete")
    }

    func testConfirmDeleteCallsServiceAndReturnsToIdle() async
    {
        let tagID = ClipTagID.user()
        let tag = ClipTag(id: tagID, name: "Work", color: .blue, source: .user)
        let afterDelete = TagSnapshot(userTags: [], tagStatesByClipID: [:])
        await seedSnapshot(userTags: [tag])
        await fake.setDefaultMutationResult(afterDelete)

        viewModel.beginDelete(tag)
        viewModel.confirmDelete()

        await waitForAsync { self.store.snapshot == afterDelete }

        XCTAssertEqual(viewModel.state, .idle, "确认后状态回到 idle")
        let calls = await fake.mutationCalls
        XCTAssertEqual(calls.count, 1)
        XCTAssertEqual(calls.first, .delete(tagID: tagID))
    }

    func testCancelDeleteRestoresIdleWithoutServiceCall() async
    {
        let tagID = ClipTagID.user()
        let tag = ClipTag(id: tagID, name: "Work", color: .blue, source: .user)
        await seedSnapshot(userTags: [tag])

        viewModel.beginDelete(tag)
        viewModel.cancelDelete()

        XCTAssertEqual(viewModel.state, .idle)
        let calls = await fake.mutationCalls
        XCTAssertTrue(calls.isEmpty)
    }

    // MARK: - TC-TM-07：service 失败回到 .idle 并由 TagStore 保持原快照

    func testConfirmRenameFailureRestoresIdleAndKeepsSnapshot() async
    {
        let tagID = ClipTagID.user()
        let tag = ClipTag(id: tagID, name: "Work", color: .blue, source: .user)
        let initial = TagSnapshot(
            userTags: [tag],
            tagStatesByClipID: [:]
        )
        await seedSnapshot(userTags: [tag])
        await fake.enqueueMutationOverride(.failure(TagError.persistenceFailed))

        viewModel.beginRename(tag)
        viewModel.draftName = "WorkRenamed"
        viewModel.submitRename()
        viewModel.confirmRename()

        await waitForAsync { self.store.failedOperation != nil }

        XCTAssertEqual(viewModel.state, .idle, "失败后状态回到 idle")
        XCTAssertEqual(store.snapshot, initial, "失败后保持最近成功快照")
        XCTAssertNotNil(store.errorMessage)
    }

    func testConfirmDeleteFailureRestoresIdleAndKeepsSnapshot() async
    {
        let tagID = ClipTagID.user()
        let tag = ClipTag(id: tagID, name: "Work", color: .blue, source: .user)
        let initial = TagSnapshot(
            userTags: [tag],
            tagStatesByClipID: [:]
        )
        await seedSnapshot(userTags: [tag])
        await fake.enqueueMutationOverride(.failure(TagError.persistenceFailed))

        viewModel.beginDelete(tag)
        viewModel.confirmDelete()

        await waitForAsync { self.store.failedOperation != nil }

        XCTAssertEqual(viewModel.state, .idle)
        XCTAssertEqual(store.snapshot, initial)
    }

    // MARK: - TC-TM-08：service 成功后所有消费者按同一 tag ID 显示新名

    func testConfirmRenameSuccessPropagatesNewNameThroughSnapshot() async
    {
        let tagID = ClipTagID.user()
        let tag = ClipTag(id: tagID, name: "Work", color: .blue, source: .user)
        await seedSnapshot(userTags: [tag])
        let renamedTag = ClipTag(id: tagID, name: "WorkRenamed", color: .blue, source: .user)
        let afterRename = TagSnapshot(
            userTags: [renamedTag],
            tagStatesByClipID: [:]
        )
        await fake.setDefaultMutationResult(afterRename)

        viewModel.beginRename(tag)
        viewModel.draftName = "WorkRenamed"
        viewModel.submitRename()
        viewModel.confirmRename()

        await waitForAsync { self.store.snapshot == afterRename }

        XCTAssertEqual(viewModel.state, .idle)
        XCTAssertEqual(store.snapshot.userTags.first?.id, tagID, "tag ID 不变")
        XCTAssertEqual(store.snapshot.userTags.first?.name, "WorkRenamed", "通过 ID 取到新名称")
    }

    // MARK: - Helpers

    private func seedSnapshot(userTags: [ClipTag]) async
    {
        let snapshot = TagSnapshot(userTags: userTags, tagStatesByClipID: [:])
        await fake.setSnapshotResult(snapshot)
        store.load()
        await waitForAsync { self.store.loadState == .ready }
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
}
