@testable import ClipMind
import XCTest

/// UnifiedPastePanelViewModel 来源过滤状态测试（F1.13 Phase 1 任务 1）。
///
/// 验证来源过滤相关的属性和逻辑：
/// - sourceApps 返回去重排序的来源应用名称
/// - filteredClips 根据选中来源过滤剪贴项
/// - showFilterOverlay 开关
/// - isSourceFilterActive 指示器
@MainActor
final class UnifiedPastePanelViewModelFilterTests: XCTestCase
{
    // MARK: - sourceApps

    func testSourceApps_returnsSortedUniqueNames()
    {
        let clips = [
            makeClip(sourceAppName: "Xcode", text: "a"),
            makeClip(sourceAppName: "Safari", text: "b"),
            makeClip(sourceAppName: "Xcode", text: "c"),
            makeClip(sourceAppName: "Notes", text: "d")
        ]
        let viewModel = UnifiedPastePanelViewModel(clips: clips)

        XCTAssertEqual(viewModel.sourceApps, ["Notes", "Safari", "Xcode"],
                       "sourceApps 应返回去重排序的来源应用名称")
    }

    func testSourceApps_emptyClips_returnsEmpty()
    {
        let viewModel = UnifiedPastePanelViewModel(clips: [])

        XCTAssertEqual(viewModel.sourceApps, [], "空剪贴项列表应返回空来源应用列表")
    }

    // MARK: - filteredClips

    func testFilteredClips_allSelected_returnsAllClips()
    {
        let clips = [
            makeClip(sourceAppName: "Xcode", text: "a"),
            makeClip(sourceAppName: "Safari", text: "b")
        ]
        let viewModel = UnifiedPastePanelViewModel(clips: clips)

        XCTAssertEqual(viewModel.filteredClips.count, 2,
                       "全部选中时应返回全部剪贴项")
    }

    func testFilteredClips_singleSourceSelected_returnsFilteredClips()
    {
        let clip1 = makeClip(sourceAppName: "Xcode", text: "a")
        let clip2 = makeClip(sourceAppName: "Safari", text: "b")
        let clip3 = makeClip(sourceAppName: "Xcode", text: "c")
        let viewModel = UnifiedPastePanelViewModel(clips: [clip1, clip2, clip3])

        viewModel.sourceFilterSelection.toggleSource("Xcode")

        let filtered = viewModel.filteredClips
        XCTAssertEqual(filtered.count, 2, "选中单个来源应过滤出对应剪贴项")
        XCTAssertTrue(filtered.allSatisfy { $0.sourceAppName == "Xcode" },
                       "过滤结果应全部来自 Xcode")
    }

    func testFilteredClips_noSourceSelected_returnsEmpty()
    {
        let clips = [
            makeClip(sourceAppName: "Xcode", text: "a"),
            makeClip(sourceAppName: "Safari", text: "b")
        ]
        let viewModel = UnifiedPastePanelViewModel(clips: clips)

        // 逐个取消选中
        viewModel.sourceFilterSelection.deselectSource("Xcode")
        viewModel.sourceFilterSelection.deselectSource("Safari")

        XCTAssertTrue(viewModel.filteredClips.isEmpty,
                      "无来源选中时应返回空列表")
    }

    // MARK: - showFilterOverlay

    func testShowFilterOverlay_initiallyFalse()
    {
        let viewModel = UnifiedPastePanelViewModel(clips: [])

        XCTAssertFalse(viewModel.showFilterOverlay,
                       "showFilterOverlay 初始应为 false")
    }

    func testToggleFilterOverlay()
    {
        let viewModel = UnifiedPastePanelViewModel(clips: [])

        viewModel.showFilterOverlay = true
        XCTAssertTrue(viewModel.showFilterOverlay)

        viewModel.showFilterOverlay = false
        XCTAssertFalse(viewModel.showFilterOverlay)
    }

    // MARK: - sourceFilterSelection 重置

    func testFilterSelection_resetsOnReinit()
    {
        let clips = [
            makeClip(sourceAppName: "Xcode", text: "a"),
            makeClip(sourceAppName: "Safari", text: "b")
        ]
        let viewModel1 = UnifiedPastePanelViewModel(clips: clips)
        viewModel1.sourceFilterSelection.toggleSource("Xcode")
        XCTAssertFalse(viewModel1.sourceFilterSelection.isAllSelected)

        let viewModel2 = UnifiedPastePanelViewModel(clips: clips)
        XCTAssertTrue(viewModel2.sourceFilterSelection.isAllSelected,
                      "重新初始化后 sourceFilterSelection 应为全部选中")
    }

    // MARK: - 来源过滤与搜索联动

    /// 来源过滤和搜索文本同时生效时，应先过滤来源再过滤搜索文本。
    func testFilteredClips_withSourceFilterAndSearchText_bothApplied()
    {
        let clips = [
            makeClip(sourceAppName: "Xcode", text: "Swift code"),
            makeClip(sourceAppName: "Xcode", text: "Python code"),
            makeClip(sourceAppName: "Safari", text: "Swift article")
        ]
        let viewModel = UnifiedPastePanelViewModel(clips: clips)

        // 选中 Xcode 后，filteredClips 应只包含 Xcode 来源的 2 项
        viewModel.sourceFilterSelection.toggleSource("Xcode")
        XCTAssertEqual(viewModel.filteredClips.count, 2)

        // 进一步在视图层按搜索文本过滤（模拟 searchFilteredClips 逻辑）
        let searchFiltered = viewModel.filteredClips.filter { clip in
            if case .text(let text) = clip.content
            {
                return text.localizedCaseInsensitiveContains("Swift")
            }
            return false
        }
        XCTAssertEqual(searchFiltered.count, 1,
                       "来源过滤 + 搜索文本过滤后应只剩 1 项")
        XCTAssertEqual(searchFiltered.first?.sourceAppName, "Xcode")
    }

    /// 来源过滤变更后，filteredClips 应立即更新。
    func testFilteredClips_sourceFilterChange_updatesImmediately()
    {
        let clips = [
            makeClip(sourceAppName: "Xcode", text: "a"),
            makeClip(sourceAppName: "Safari", text: "b")
        ]
        let viewModel = UnifiedPastePanelViewModel(clips: clips)

        XCTAssertEqual(viewModel.filteredClips.count, 2, "初始全部选中")

        viewModel.sourceFilterSelection.toggleSource("Xcode")
        XCTAssertEqual(viewModel.filteredClips.count, 1,
                       "切换为单选后立即更新")

        viewModel.sourceFilterSelection.toggleAll()
        XCTAssertEqual(viewModel.filteredClips.count, 2,
                       "切回全部后立即恢复")
    }

    /// isSourceFilterActive 在部分选中时为 true。
    func testIsSourceFilterActive_trueWhenPartialSelected()
    {
        let clips = [
            makeClip(sourceAppName: "Xcode", text: "a"),
            makeClip(sourceAppName: "Safari", text: "b")
        ]
        let viewModel = UnifiedPastePanelViewModel(clips: clips)

        XCTAssertFalse(viewModel.isSourceFilterActive, "全部选中时为 false")

        viewModel.sourceFilterSelection.toggleSource("Xcode")
        XCTAssertTrue(viewModel.isSourceFilterActive, "部分选中时为 true")

        viewModel.sourceFilterSelection.toggleAll()
        XCTAssertFalse(viewModel.isSourceFilterActive, "重置为全部后为 false")
    }

    // MARK: - Helper

    private func makeClip(sourceAppName: String, text: String = "test") -> ClipItem
    {
        ClipItem.makeText(
            text,
            contentType: .other,
            sourceApp: "com.test.\(sourceAppName.lowercased())",
            sourceAppName: sourceAppName
        )
    }
}
