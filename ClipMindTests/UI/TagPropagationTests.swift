@testable import ClipMind
import Foundation
import XCTest

// MARK: - TagPropagationTests

/// F1.14 Phase 4 任务 3：标签重命名/删除的全局传播测试。
///
/// 通过 `FakeTagService`（定义于 `TagPickerViewModelTests.swift`）驱动 `TagStore`，验证：
/// - 三入口通过 `TagStore.tags(for:)` 立即得到新名（TagStore 是 @MainActor，测试需 @MainActor）；
/// - 重命名不改变 tag ID、颜色和关联顺序；
/// - 删除移除用户目录条目和所有 clip state 中的 ID；
/// - `TagFilterSelection.selectedTagIDs` 经 `formIntersection(validTagIDs)` 自动移除目标；
/// - 其他搜索与来源条件保持。
///
/// 独立文件避免 `CompositeClipFilterTests.swift` 超过 500 行文件长度限制。
@MainActor
final class TagPropagationTests: XCTestCase
{
    private var fake: FakeTagService!
    private var coordinator: TagMigrationCoordinator!
    private var store: TagStore!

    /// 测试专用条目 ID。
    private let clipID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!

    /// 用户标签「工作」的稳定 ID。
    private let workTagID = ClipTagID.user(
        UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    )

    /// 用户标签「待处理」的稳定 ID。
    private let pendingTagID = ClipTagID.user(
        UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
    )

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

    // MARK: - 重命名传播

    /// 三入口通过 `TagStore.tags(for:)` 立即得到新名。
    func testRenamePropagates_newNameAvailableThroughTagsFor() async
    {
        let initial = makeSnapshot(tagName: "工作")
        await seedSnapshot(initial)

        let renamedTag = ClipTag(
            id: workTagID, name: "工作已重命名", color: .blue, source: .user
        )
        let afterRename = TagSnapshot(
            userTags: [renamedTag, pendingTag()],
            tagStatesByClipID: initial.tagStatesByClipID
        )
        await fake.setDefaultMutationResult(afterRename)

        store.perform(.rename(tagID: workTagID, name: "工作已重命名"))
        await waitForAsync { self.store.snapshot.userTags.first?.name == "工作已重命名" }

        let tags = store.tags(for: clipID)
        let workTag = tags.first { $0.id == workTagID }
        XCTAssertEqual(
            workTag?.name, "工作已重命名",
            "三入口通过 TagStore.tags(for:) 应得到新名称"
        )
    }

    /// 重命名不改变 tag ID、颜色和关联顺序。
    func testRenamePropagates_tagIDColorAndOrderUnchanged() async
    {
        let initial = makeSnapshot(tagName: "工作")
        await seedSnapshot(initial)
        let originalTagIDs = initial.tagStatesByClipID[clipID]?.orderedTagIDs

        let renamedTag = ClipTag(
            id: workTagID, name: "工作已重命名", color: .blue, source: .user
        )
        let afterRename = TagSnapshot(
            userTags: [renamedTag, pendingTag()],
            tagStatesByClipID: initial.tagStatesByClipID
        )
        await fake.setDefaultMutationResult(afterRename)

        store.perform(.rename(tagID: workTagID, name: "工作已重命名"))
        await waitForAsync { self.store.snapshot.userTags.first?.name == "工作已重命名" }

        let tags = store.tags(for: clipID)
        XCTAssertEqual(tags.first?.id, .system(.code), "首位仍是系统标签")
        let workTag = tags.first { $0.id == workTagID }
        XCTAssertEqual(workTag?.color, .blue, "颜色不变")
        XCTAssertEqual(
            tags.map(\.id), originalTagIDs,
            "关联顺序不变"
        )
    }

    /// 活动筛选 chip 显示新名称，resultId 集合不变。
    func testRenamePropagates_filterResultIDsUnchanged() async
    {
        let clips = CompositeClipFilterFixtures.clips
        let initial = CompositeClipFilterFixtures.snapshot
        await seedSnapshot(initial)

        let importantTagID = CompositeClipFilterFixtures.importantTagID
        let renamedImportant = ClipTag(
            id: importantTagID, name: "重要Renamed", color: .rose, source: .user
        )
        let pendingTagCopy = ClipTag(
            id: CompositeClipFilterFixtures.pendingTagID,
            name: "待处理", color: .amber, source: .user
        )
        let afterRename = TagSnapshot(
            userTags: [renamedImportant, pendingTagCopy],
            tagStatesByClipID: initial.tagStatesByClipID
        )
        await fake.setDefaultMutationResult(afterRename)

        let intent = ClipFilterIntent(
            query: "",
            selectedSourceApps: CompositeClipFilterFixtures.allSources,
            allSourceApps: CompositeClipFilterFixtures.allSources,
            selectedTagIDs: [importantTagID]
        )
        let beforeRename = CompositeClipFilter.filter(
            clips, intent: intent, snapshot: initial
        )

        store.perform(.rename(tagID: importantTagID, name: "重要Renamed"))
        await waitForAsync {
            self.store.snapshot.userTags.first(where: { $0.id == importantTagID })?.name
                == "重要Renamed"
        }

        let afterRenameResult = CompositeClipFilter.filter(
            clips, intent: intent, snapshot: store.snapshot
        )
        XCTAssertEqual(
            beforeRename.map(\.id), afterRenameResult.map(\.id),
            "重命名不改变 resultId 集合"
        )

        // 验证 chip 通过新 snapshot 能取到新名（TagFilterView.tagByID 行为）
        let renamedTagInSnapshot = store.snapshot.allTags.first { $0.id == importantTagID }
        XCTAssertEqual(
            renamedTagInSnapshot?.name, "重要Renamed",
            "活动 chip 通过 stable ID 取到新名称"
        )
    }

    // MARK: - 删除传播

    /// snapshot 用户目录不含目标。
    func testDeletePropagates_snapshotExcludesTarget() async
    {
        let initial = makeSnapshot(tagName: "工作")
        await seedSnapshot(initial)

        let afterDelete = TagSnapshot(
            userTags: [pendingTag()],
            tagStatesByClipID: [
                clipID: ClipTagState(
                    orderedTagIDs: [.system(.code), pendingTagID],
                    systemTagDisposition: .associated,
                    migrationVersion: ClipTagState.currentMigrationVersion
                )
            ]
        )
        await fake.setDefaultMutationResult(afterDelete)

        store.perform(.delete(tagID: workTagID))
        await waitForAsync { !self.store.snapshot.userTags.contains { $0.id == self.workTagID } }

        XCTAssertFalse(
            store.snapshot.userTags.contains { $0.id == workTagID },
            "snapshot 用户目录不含目标"
        )
    }

    /// 所有 clip state 不含目标 ID。
    func testDeletePropagates_clipStatesExcludeTargetID() async
    {
        let initial = makeSnapshot(tagName: "工作")
        await seedSnapshot(initial)

        let afterDelete = TagSnapshot(
            userTags: [pendingTag()],
            tagStatesByClipID: [
                clipID: ClipTagState(
                    orderedTagIDs: [.system(.code), pendingTagID],
                    systemTagDisposition: .associated,
                    migrationVersion: ClipTagState.currentMigrationVersion
                )
            ]
        )
        await fake.setDefaultMutationResult(afterDelete)

        store.perform(.delete(tagID: workTagID))
        await waitForAsync { !self.store.snapshot.userTags.contains { $0.id == self.workTagID } }

        for (_, state) in store.snapshot.tagStatesByClipID
        {
            XCTAssertFalse(
                state.orderedTagIDs.contains(workTagID),
                "所有 clip state 不含目标 ID"
            )
        }
    }

    /// `TagFilterSelection.selectedTagIDs` 经 formIntersection 自动移除目标，其他选择保持。
    func testDeletePropagates_formIntersectionRemovesTargetFromSelection() async
    {
        let initial = makeSnapshot(tagName: "工作")
        await seedSnapshot(initial)

        var selection = TagFilterSelection()
        selection.toggle(workTagID)
        selection.toggle(pendingTagID)
        XCTAssertTrue(selection.isSelected(workTagID))
        XCTAssertTrue(selection.isSelected(pendingTagID))

        let afterDelete = TagSnapshot(
            userTags: [pendingTag()],
            tagStatesByClipID: [
                clipID: ClipTagState(
                    orderedTagIDs: [.system(.code), pendingTagID],
                    systemTagDisposition: .associated,
                    migrationVersion: ClipTagState.currentMigrationVersion
                )
            ]
        )
        await fake.setDefaultMutationResult(afterDelete)

        store.perform(.delete(tagID: workTagID))
        await waitForAsync { !self.store.snapshot.userTags.contains { $0.id == self.workTagID } }

        // 模拟 MainWindow.onChange 中的清理逻辑：
        // validTagIDs = Set(tagStore.snapshot.allTags.map(\.id))
        // tagFilterSelection.selectedTagIDs.formIntersection(validTagIDs)
        let validTagIDs = Set(store.snapshot.allTags.map(\.id))
        selection.selectedTagIDs.formIntersection(validTagIDs)

        XCTAssertFalse(
            selection.isSelected(workTagID),
            "TagFilterSelection.selectedTagIDs 自动移除目标"
        )
        XCTAssertTrue(
            selection.isSelected(pendingTagID),
            "其他标签选择保持"
        )
    }

    /// 其他搜索与来源条件保持。
    func testDeletePropagates_otherSearchAndSourceConditionsKept() async
    {
        let clips = CompositeClipFilterFixtures.clips
        let initial = CompositeClipFilterFixtures.snapshot
        await seedSnapshot(initial)

        let importantTagID = CompositeClipFilterFixtures.importantTagID

        // 删除 importantTagID 后的 snapshot：userTags 移除目标，
        // 所有 clip state 的 orderedTagIDs 移除目标 ID。
        let afterDelete = TagSnapshot(
            userTags: [
                ClipTag(
                    id: CompositeClipFilterFixtures.pendingTagID,
                    name: "待处理", color: .amber, source: .user
                )
            ],
            tagStatesByClipID: initial.tagStatesByClipID.mapValues
            { state in
                ClipTagState(
                    orderedTagIDs: state.orderedTagIDs.filter { $0 != importantTagID },
                    systemTagDisposition: state.systemTagDisposition,
                    migrationVersion: state.migrationVersion
                )
            }
        )
        await fake.setDefaultMutationResult(afterDelete)

        store.perform(.delete(tagID: importantTagID))
        await waitForAsync {
            !self.store.snapshot.userTags.contains { $0.id == importantTagID }
        }

        // 验证 search + source 条件仍然有效
        let intent = ClipFilterIntent(
            query: "需求",
            selectedSourceApps: ["Pages"],
            allSourceApps: CompositeClipFilterFixtures.allSources,
            selectedTagIDs: []
        )
        let result = CompositeClipFilter.filter(
            clips, intent: intent, snapshot: store.snapshot
        )
        XCTAssertEqual(result.count, 2, "需求 + Pages 仍返回 2 条")
        XCTAssertTrue(
            result.allSatisfy { $0.sourceAppName == "Pages" },
            "来源条件保持"
        )
        XCTAssertTrue(
            result.allSatisfy
            {
                if case .text(let text) = $0.content
                {
                    return text.localizedCaseInsensitiveContains("需求")
                }
                return false
            },
            "搜索条件保持"
        )
    }

    // MARK: - Helpers

    private func pendingTag() -> ClipTag
    {
        ClipTag(id: pendingTagID, name: "待处理", color: .amber, source: .user)
    }

    private func makeSnapshot(tagName: String) -> TagSnapshot
    {
        let workTag = ClipTag(id: workTagID, name: tagName, color: .blue, source: .user)
        let state = ClipTagState(
            orderedTagIDs: [.system(.code), workTagID, pendingTagID],
            systemTagDisposition: .associated,
            migrationVersion: ClipTagState.currentMigrationVersion
        )
        return TagSnapshot(
            userTags: [workTag, pendingTag()],
            tagStatesByClipID: [clipID: state]
        )
    }

    private func seedSnapshot(_ snapshot: TagSnapshot) async
    {
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
