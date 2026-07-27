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
