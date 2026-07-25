@testable import ClipMind
import XCTest

/// UnifiedPastePanelViewModel 单元测试（Phase 1 任务 1）。
///
/// 验证视图状态管理器的基础契约：
/// - 默认高亮第一行（空列表时 selectedIndex = -1）
/// - isSelected / selectIndex / moveSelectionUp / moveSelectionDown
/// - handleDoubleClick 按 clip 查找（文本触发回调，图片/文件路径显示提示）
/// - handleEnterKey / handleEscKey 回调路由
@MainActor
final class UnifiedPastePanelViewModelTests: XCTestCase
{
    func testInit_WithNonEmptyClips_DefaultsSelectedIndexToZero()
    {
        let clips = ClipTestData.previewClips
        let viewModel = UnifiedPastePanelViewModel(clips: clips)

        XCTAssertEqual(viewModel.selectedIndex, 0, "非空列表默认高亮第一行（索引 0）")
    }

    func testInit_WithEmptyClips_DefaultsSelectedIndexToMinusOne()
    {
        let viewModel = UnifiedPastePanelViewModel(clips: [])

        XCTAssertEqual(viewModel.selectedIndex, -1, "空列表 selectedIndex = -1，无高亮")
    }

    func testSelectIndex_UpdatesSelectedIndexAndClearsHint()
    {
        let clips = ClipTestData.previewClips
        let viewModel = UnifiedPastePanelViewModel(clips: clips)
        viewModel.shouldShowTextOnlyHint = true

        viewModel.selectIndex(1)

        XCTAssertEqual(viewModel.selectedIndex, 1)
        XCTAssertFalse(viewModel.shouldShowTextOnlyHint, "切换选中时清除文本提示")
    }

    func testSelectIndex_OutOfBounds_IsIgnored()
    {
        let clips = ClipTestData.previewClips
        let viewModel = UnifiedPastePanelViewModel(clips: clips)

        viewModel.selectIndex(-1)
        XCTAssertEqual(viewModel.selectedIndex, 0, "负索引被忽略")

        viewModel.selectIndex(clips.count)
        XCTAssertEqual(viewModel.selectedIndex, 0, "越界索引被忽略")
    }

    func testMoveSelectionDown_AdvancesSelectedIndex()
    {
        let clips = ClipTestData.previewClips
        let viewModel = UnifiedPastePanelViewModel(clips: clips)

        viewModel.moveSelectionDown()
        XCTAssertEqual(viewModel.selectedIndex, 1)
    }

    func testMoveSelectionDown_AtLastIndex_StaysAtLast()
    {
        let clips = ClipTestData.previewClips
        let viewModel = UnifiedPastePanelViewModel(clips: clips)
        viewModel.selectIndex(clips.count - 1)

        viewModel.moveSelectionDown()

        XCTAssertEqual(viewModel.selectedIndex, clips.count - 1, "末行按下不动")
    }

    func testMoveSelectionUp_AtFirstIndex_StaysAtFirst()
    {
        let clips = ClipTestData.previewClips
        let viewModel = UnifiedPastePanelViewModel(clips: clips)

        viewModel.moveSelectionUp()

        XCTAssertEqual(viewModel.selectedIndex, 0, "首行按上不动")
    }

    func testHandleDoubleClick_TextClip_TriggersPasteCallback()
    {
        let textClip = ClipItem.makeText(
            "hello",
            contentType: .other,
            sourceApp: "com.test",
            sourceAppName: "Test"
        )
        let viewModel = UnifiedPastePanelViewModel(clips: [textClip])
        var triggeredClip: ClipItem?
        viewModel.onPasteTriggered = { clip in triggeredClip = clip }

        viewModel.handleDoubleClick(clip: textClip)

        XCTAssertEqual(triggeredClip?.id, textClip.id, "文本类型双击触发 onPasteTriggered")
        XCTAssertFalse(viewModel.shouldShowTextOnlyHint, "文本类型不显示提示")
    }

    func testHandleDoubleClick_ImageClip_ShowsHintAndDoesNotTrigger()
    {
        let imageClip = ClipItem.makeImage(
            Data([0x89, 0x50, 0x4E, 0x47]),
            contentType: .other,
            sourceApp: "com.test",
            sourceAppName: "Test"
        )
        let viewModel = UnifiedPastePanelViewModel(clips: [imageClip])
        var triggered = false
        viewModel.onPasteTriggered = { _ in triggered = true }

        viewModel.handleDoubleClick(clip: imageClip)

        XCTAssertTrue(viewModel.shouldShowTextOnlyHint, "图片类型显示提示")
        XCTAssertFalse(triggered, "图片类型不触发粘贴回调")
    }

    func testHandleEnterKey_TriggersPasteCallbackForSelectedClip()
    {
        let clips = ClipTestData.previewClips
        let viewModel = UnifiedPastePanelViewModel(clips: clips)
        var triggeredClip: ClipItem?
        viewModel.onPasteTriggered = { clip in triggeredClip = clip }

        viewModel.handleEnterKey()

        XCTAssertEqual(triggeredClip?.id, clips[0].id, "回车触发当前高亮行的粘贴回调")
    }

    func testHandleEscKey_TriggersEscCallback()
    {
        let viewModel = UnifiedPastePanelViewModel(clips: ClipTestData.previewClips)
        var escCalled = false
        viewModel.onEscPressed = { escCalled = true }

        viewModel.handleEscKey()

        XCTAssertTrue(escCalled, "Esc 键触发 onEscPressed 回调")
    }
}
