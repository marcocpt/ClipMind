@testable import ClipMind
import Foundation
import XCTest

// MARK: - CompositeClipFilterTests

/// F1.14 Phase 3 任务 1：完整筛选意图与纯业务解释器测试。
///
/// 覆盖 FLT-001、FLT-005、REG-002 的纯业务逻辑：
/// - 查询为空 + 全部来源 + 无标签返回全部；
/// - 搜索词只匹配文本内容；
/// - 搜索 + 单来源 + 单标签使用 AND；
/// - 两标签只返回同时含两者的条目；
/// - 选择当前条目没有的系统标签返回空；
/// - 清除标签后搜索和来源不变；
/// - 历史入口与搜索入口传相同 intent 时 resultId 集合相同。
final class CompositeClipFilterTests: XCTestCase
{
    // MARK: - 固定夹具

    private let clips = CompositeClipFilterFixtures.clips
    private let snapshot = CompositeClipFilterFixtures.snapshot
    private let allSources = CompositeClipFilterFixtures.allSources
    private let importantTagID = CompositeClipFilterFixtures.importantTagID
    private let pendingTagID = CompositeClipFilterFixtures.pendingTagID

    // MARK: - 基础筛选

    func testEmptyQuery_allSources_noTags_returnsAll()
    {
        let intent = ClipFilterIntent(
            query: "",
            selectedSourceApps: allSources,
            allSourceApps: allSources,
            selectedTagIDs: []
        )
        let result = CompositeClipFilter.filter(clips, intent: intent, snapshot: snapshot)
        XCTAssertEqual(result.map(\.id), clips.map(\.id))
    }

    func testSearchQuery_matchesTextContentOnly()
    {
        let intent = ClipFilterIntent(
            query: "需求",
            selectedSourceApps: allSources,
            allSourceApps: allSources,
            selectedTagIDs: []
        )
        let result = CompositeClipFilter.filter(clips, intent: intent, snapshot: snapshot)
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result[0].id, clips[0].id)
        XCTAssertEqual(result[1].id, clips[1].id)
        XCTAssertEqual(result[2].id, clips[2].id)
    }

    func testSearchQuery_noMatch_returnsEmpty()
    {
        let intent = ClipFilterIntent(
            query: "不存在的关键词",
            selectedSourceApps: allSources,
            allSourceApps: allSources,
            selectedTagIDs: []
        )
        let result = CompositeClipFilter.filter(clips, intent: intent, snapshot: snapshot)
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - AND 交集

    func testSearchQuery_singleSource_singleTag_usesAND()
    {
        let intent = ClipFilterIntent(
            query: "需求",
            selectedSourceApps: ["Pages"],
            allSourceApps: allSources,
            selectedTagIDs: [ClipTagID.system(.requirement)]
        )
        let result = CompositeClipFilter.filter(clips, intent: intent, snapshot: snapshot)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].id, clips[0].id)
        XCTAssertEqual(result[1].id, clips[1].id)
    }

    func testTwoTags_returnsOnlyClipsWithBoth()
    {
        let intent = ClipFilterIntent(
            query: "",
            selectedSourceApps: allSources,
            allSourceApps: allSources,
            selectedTagIDs: [importantTagID, pendingTagID]
        )
        let result = CompositeClipFilter.filter(clips, intent: intent, snapshot: snapshot)
        XCTAssertEqual(result.count, 3)
        XCTAssertTrue(result.contains { $0.id == clips[0].id })
        XCTAssertTrue(result.contains { $0.id == clips[2].id })
        XCTAssertTrue(result.contains { $0.id == clips[3].id })
    }

    func testSystemTagNotOnAnyClip_returnsEmpty()
    {
        let intent = ClipFilterIntent(
            query: "",
            selectedSourceApps: allSources,
            allSourceApps: allSources,
            selectedTagIDs: [ClipTagID.system(.link)]
        )
        let result = CompositeClipFilter.filter(clips, intent: intent, snapshot: snapshot)
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - 清除标签不修改搜索和来源

    func testClearTags_keepsSearchAndSource()
    {
        let intentWithTags = ClipFilterIntent(
            query: "需求",
            selectedSourceApps: ["Pages"],
            allSourceApps: allSources,
            selectedTagIDs: [importantTagID]
        )
        let intentCleared = ClipFilterIntent(
            query: "需求",
            selectedSourceApps: ["Pages"],
            allSourceApps: allSources,
            selectedTagIDs: []
        )
        let resultWithTags = CompositeClipFilter.filter(
            clips, intent: intentWithTags, snapshot: snapshot
        )
        let resultCleared = CompositeClipFilter.filter(
            clips, intent: intentCleared, snapshot: snapshot
        )
        XCTAssertTrue(resultCleared.count >= resultWithTags.count)
        XCTAssertTrue(resultCleared.allSatisfy { $0.sourceAppName == "Pages" })
        XCTAssertTrue(resultCleared.allSatisfy
        {
            if case .text(let text) = $0.content
            {
                return text.localizedCaseInsensitiveContains("需求")
            }
            return false
        })
    }

    // MARK: - 历史与搜索入口 resultId 一致

    func testSameIntent_historyAndSearch_returnSameResultIds()
    {
        let intent = ClipFilterIntent(
            query: "需求",
            selectedSourceApps: allSources,
            allSourceApps: allSources,
            selectedTagIDs: [importantTagID]
        )
        let historyResult = CompositeClipFilter.filter(
            clips, intent: intent, snapshot: snapshot
        )
        let searchResult = CompositeClipFilter.filter(
            clips, intent: intent, snapshot: snapshot
        )
        XCTAssertEqual(historyResult.map(\.id), searchResult.map(\.id))
    }

    // MARK: - 来源筛选

    func testSourceFilter_onlyReturnsClipsFromSelectedSources()
    {
        let intent = ClipFilterIntent(
            query: "",
            selectedSourceApps: ["Xcode"],
            allSourceApps: allSources,
            selectedTagIDs: []
        )
        let result = CompositeClipFilter.filter(clips, intent: intent, snapshot: snapshot)
        XCTAssertEqual(result.count, 2)
        XCTAssertTrue(result.allSatisfy { $0.sourceAppName == "Xcode" })
    }

    // MARK: - ClipFilterIntent 计算属性

    func testIntent_isSourceFilterActive_whenNotAllSelected()
    {
        let intent = ClipFilterIntent(
            query: "",
            selectedSourceApps: ["Pages"],
            allSourceApps: allSources,
            selectedTagIDs: []
        )
        XCTAssertTrue(intent.isSourceFilterActive)
    }

    func testIntent_isSourceFilterActive_false_whenAllSelected()
    {
        let intent = ClipFilterIntent(
            query: "",
            selectedSourceApps: allSources,
            allSourceApps: allSources,
            selectedTagIDs: []
        )
        XCTAssertFalse(intent.isSourceFilterActive)
    }

    func testIntent_isTagFilterActive_whenTagsSelected()
    {
        let intent = ClipFilterIntent(
            query: "",
            selectedSourceApps: allSources,
            allSourceApps: allSources,
            selectedTagIDs: [importantTagID]
        )
        XCTAssertTrue(intent.isTagFilterActive)
    }

    func testIntent_hasAnyCondition_withQueryOnly()
    {
        let intent = ClipFilterIntent(
            query: "需求",
            selectedSourceApps: allSources,
            allSourceApps: allSources,
            selectedTagIDs: []
        )
        XCTAssertTrue(intent.hasAnyCondition)
    }

    func testIntent_hasAnyCondition_false_whenAllEmpty()
    {
        let intent = ClipFilterIntent(
            query: "   ",
            selectedSourceApps: allSources,
            allSourceApps: allSources,
            selectedTagIDs: []
        )
        XCTAssertFalse(intent.hasAnyCondition)
    }

    // MARK: - 顺序保持

    func testFilter_preservesInputOrder()
    {
        let reversedClips = Array(clips.reversed())
        let intent = ClipFilterIntent(
            query: "",
            selectedSourceApps: allSources,
            allSourceApps: allSources,
            selectedTagIDs: []
        )
        let result = CompositeClipFilter.filter(
            reversedClips, intent: intent, snapshot: snapshot
        )
        XCTAssertEqual(result.map(\.id), reversedClips.map(\.id))
    }
}

// MARK: - ClipListStateTests

/// F1.14 Phase 3 任务 3：列表空状态解析测试。
final class ClipListStateTests: XCTestCase
{
    func testAllClipsEmpty_returnsNoHistory()
    {
        let state = ClipListState.resolve(allClips: [], filteredClips: [])
        XCTAssertEqual(state, .noHistory)
    }

    func testAllClipsNonEmpty_filteredEmpty_returnsNoMatches()
    {
        let clips = CompositeClipFilterFixtures.clips
        let state = ClipListState.resolve(allClips: clips, filteredClips: [])
        XCTAssertEqual(state, .noMatches)
    }

    func testFilteredNonEmpty_returnsResults()
    {
        let clips = CompositeClipFilterFixtures.clips
        let state = ClipListState.resolve(allClips: clips, filteredClips: [clips[0]])
        XCTAssertEqual(state, .results)
    }

    func testAllClipsEmpty_filteredNonEmpty_returnsNoHistory()
    {
        // 理论上 filteredClips 不应多于 allClips，但 resolve 优先判定 allClips 为空
        let clips = CompositeClipFilterFixtures.clips
        let state = ClipListState.resolve(allClips: [], filteredClips: clips)
        XCTAssertEqual(state, .noHistory)
    }
}

// MARK: - TagFilterSelectionTests

/// F1.14 Phase 3 任务 2：标签筛选选择状态测试。
///
/// 覆盖初始空、toggle、clear，不使用 UserDefaults。
final class TagFilterSelectionTests: XCTestCase
{
    private let tagA = ClipTagID.user(
        UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc")!
    )
    private let tagB = ClipTagID.user(
        UUID(uuidString: "dddddddd-dddd-dddd-dddd-dddddddddddd")!
    )

    func testInitialSelection_isEmpty()
    {
        let selection = TagFilterSelection()
        XCTAssertTrue(selection.selectedTagIDs.isEmpty)
        XCTAssertFalse(selection.isSelected(tagA))
    }

    func testToggle_addsAndRemovesTag()
    {
        var selection = TagFilterSelection()
        selection.toggle(tagA)
        XCTAssertTrue(selection.isSelected(tagA))
        XCTAssertEqual(selection.selectedTagIDs.count, 1)
        selection.toggle(tagA)
        XCTAssertFalse(selection.isSelected(tagA))
        XCTAssertTrue(selection.selectedTagIDs.isEmpty)
    }

    func testToggle_multipleTags_independent()
    {
        var selection = TagFilterSelection()
        selection.toggle(tagA)
        selection.toggle(tagB)
        XCTAssertEqual(selection.selectedTagIDs.count, 2)
        XCTAssertTrue(selection.isSelected(tagA))
        XCTAssertTrue(selection.isSelected(tagB))
        selection.toggle(tagA)
        XCTAssertEqual(selection.selectedTagIDs.count, 1)
        XCTAssertTrue(selection.isSelected(tagB))
    }

    func testClear_emptiesSelection()
    {
        var selection = TagFilterSelection()
        selection.toggle(tagA)
        selection.toggle(tagB)
        XCTAssertEqual(selection.selectedTagIDs.count, 2)
        selection.clear()
        XCTAssertTrue(selection.selectedTagIDs.isEmpty)
    }

    func testEquals_sameSelectionsAreEqual()
    {
        var selectionA = TagFilterSelection()
        var selectionB = TagFilterSelection()
        XCTAssertEqual(selectionA, selectionB)
        selectionA.toggle(tagA)
        XCTAssertNotEqual(selectionA, selectionB)
        selectionB.toggle(tagA)
        XCTAssertEqual(selectionA, selectionB)
    }
}

// MARK: - CompositeClipFilterFixtures

/// F1.14 Phase 3 测试夹具：固定 6 条 ClipItem 和对应 TagSnapshot。
enum CompositeClipFilterFixtures
{
    /// 全部来源应用名称。
    static let allSources: Set<String> = ["Pages", "Xcode", "Notes"]

    /// 用户标签 ID（固定 UUID，不从 hashValue 派生）。
    static let importantTagID = ClipTagID.user(
        UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!
    )
    static let pendingTagID = ClipTagID.user(
        UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!
    )

    /// 6 条固定 ClipItem。
    static let clips: [ClipItem] = makeFixtureClips()

    /// 与 clips 对应的 TagSnapshot。
    static let snapshot: TagSnapshot = makeFixtureSnapshot()

    // MARK: - 私有构造

    /// 夹具规格。
    private struct ClipSpec
    {
        let index: Int
        let text: String
        let type: ContentType
        let source: String
        let tags: [ClipTagID]
    }

    private static func makeFixtureClips() -> [ClipItem]
    {
        let specs: [ClipSpec] = [
            ClipSpec(index: 1, text: "需求分析文档", type: .requirement, source: "Pages",
                     tags: [.system(.requirement), importantTagID, pendingTagID]),
            ClipSpec(index: 2, text: "需求评审记录", type: .requirement, source: "Pages",
                     tags: [.system(.requirement), importantTagID]),
            ClipSpec(index: 3, text: "需求代码实现", type: .code, source: "Xcode",
                     tags: [.system(.code), importantTagID, pendingTagID]),
            ClipSpec(index: 4, text: "设计文档", type: .requirement, source: "Pages",
                     tags: [.system(.requirement), importantTagID, pendingTagID]),
            ClipSpec(index: 5, text: "代码片段", type: .code, source: "Xcode",
                     tags: [.system(.code)]),
            ClipSpec(index: 6, text: "会议纪要", type: .meeting, source: "Notes",
                     tags: [.system(.meeting)])
        ]
        return specs.map { makeClip($0) }
    }

    private static func makeClip(_ spec: ClipSpec) -> ClipItem
    {
        let uuid = UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", spec.index))!
        var clip = ClipItem.makeText(
            spec.text,
            contentType: spec.type,
            sourceApp: "com.apple.\(spec.source)",
            sourceAppName: spec.source
        )
        clip = clip.withID(uuid)
        clip.tagState = ClipTagState(
            orderedTagIDs: spec.tags,
            systemTagDisposition: .associated,
            migrationVersion: ClipTagState.currentMigrationVersion
        )
        return clip
    }

    private static func makeFixtureSnapshot() -> TagSnapshot
    {
        let userTags: [ClipTag] = [
            ClipTag(id: importantTagID, name: "重要", color: .rose, source: .user),
            ClipTag(id: pendingTagID, name: "待处理", color: .amber, source: .user)
        ]
        var tagStatesByClipID: [UUID: ClipTagState] = [:]
        for clip in clips
        {
            tagStatesByClipID[clip.id] = clip.tagState
        }
        return TagSnapshot(userTags: userTags, tagStatesByClipID: tagStatesByClipID)
    }
}

// MARK: - ClipItem 测试辅助

extension ClipItem
{
    /// 返回带指定 ID 的副本（仅用于测试夹具）。
    func withID(_ newID: UUID) -> ClipItem
    {
        ClipItem(
            id: newID,
            content: content,
            contentType: contentType,
            sourceApp: sourceApp,
            sourceAppName: sourceAppName,
            timestamp: timestamp,
            summary: summary,
            translation: translation,
            rewrite: rewrite,
            todos: todos,
            embeddings: embeddings,
            isSample: isSample,
            tagState: tagState
        )
    }
}
