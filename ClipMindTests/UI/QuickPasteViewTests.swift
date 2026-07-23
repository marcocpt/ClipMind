@testable import ClipMind
import XCTest

final class QuickPasteViewTests: XCTestCase
{
    // MARK: - TC-F1.9-4-03 面板出现时默认高亮第一行

    @MainActor
    func testViewInit_DefaultSelectedIndexIsZero_WhenListNonEmpty()
    {
        let clips = QuickPasteViewTests.makeTextClips(count: 3)
        let viewModel = QuickPasteViewModel(clips: clips)

        XCTAssertEqual(viewModel.selectedIndex, 0, "列表非空时应默认高亮第一行")
        XCTAssertTrue(viewModel.isSelected(index: 0), "第一行应被选中")
    }

    // MARK: - TC-F1.9-4-04 第一行按上方向键不动

    @MainActor
    func testMoveSelectionUp_OnFirstIndex_StaysAtZero()
    {
        let clips = QuickPasteViewTests.makeTextClips(count: 3)
        let viewModel = QuickPasteViewModel(clips: clips)
        viewModel.selectedIndex = 0

        viewModel.moveSelectionUp()

        XCTAssertEqual(viewModel.selectedIndex, 0, "第一行按上方向键应不动")
    }

    // MARK: - 方向键下移

    @MainActor
    func testMoveSelectionDown_FromFirstIndex_MovesToSecond()
    {
        let clips = QuickPasteViewTests.makeTextClips(count: 3)
        let viewModel = QuickPasteViewModel(clips: clips)
        viewModel.selectedIndex = 0

        viewModel.moveSelectionDown()

        XCTAssertEqual(viewModel.selectedIndex, 1, "第一行按下方向键应移到第二行")
    }

    // MARK: - 最后一行按下方向键不动

    @MainActor
    func testMoveSelectionDown_OnLastIndex_StaysAtLast()
    {
        let clips = QuickPasteViewTests.makeTextClips(count: 3)
        let viewModel = QuickPasteViewModel(clips: clips)
        viewModel.selectedIndex = 2

        viewModel.moveSelectionDown()

        XCTAssertEqual(viewModel.selectedIndex, 2, "最后一行按下方向键应不动")
    }

    // MARK: - TC-F1.9-5-03 未高亮行按回车不触发操作（空列表）

    @MainActor
    func testEnterKey_OnEmptyList_DoesNotTriggerPaste()
    {
        let viewModel = QuickPasteViewModel(clips: [])
        var pasteCalled = false
        viewModel.onPasteTriggered = { _ in pasteCalled = true }

        viewModel.handleEnterKey()

        XCTAssertFalse(pasteCalled, "空列表按回车不应触发粘贴")
    }

    // MARK: - 单击选中

    @MainActor
    func testSelectIndex_UpdatesSelectedIndex()
    {
        let clips = QuickPasteViewTests.makeTextClips(count: 3)
        let viewModel = QuickPasteViewModel(clips: clips)

        viewModel.selectIndex(1)

        XCTAssertEqual(viewModel.selectedIndex, 1)
        XCTAssertTrue(viewModel.isSelected(index: 1))
        XCTAssertFalse(viewModel.isSelected(index: 0))
    }

    // MARK: - TC-F1.9-5-01 双击文本行触发粘贴流程

    @MainActor
    func testHandleDoubleClick_OnTextRow_TriggersPasteCallback()
    {
        let clips = QuickPasteViewTests.makeTextClips(count: 3)
        let viewModel = QuickPasteViewModel(clips: clips)
        var pastedClip: ClipItem?
        viewModel.onPasteTriggered = { clip in pastedClip = clip }

        viewModel.handleDoubleClick(index: 0)

        XCTAssertNotNil(pastedClip, "双击文本行应触发粘贴回调")
        XCTAssertEqual(pastedClip?.id, clips[0].id)
    }

    // MARK: - TC-F1.9-11-01 双击图片类型行显示提示不粘贴

    @MainActor
    func testHandleDoubleClick_OnImageRow_DoesNotPaste_AndShowsHint()
    {
        let imageClip = ClipItem.makeImage(
            Data([0x89, 0x50, 0x4E, 0x47]),
            contentType: .other,
            sourceApp: "com.test",
            sourceAppName: "Test"
        )
        let viewModel = QuickPasteViewModel(clips: [imageClip])
        var pasteCalled = false
        viewModel.onPasteTriggered = { _ in pasteCalled = true }

        viewModel.handleDoubleClick(index: 0)

        XCTAssertFalse(pasteCalled, "双击图片行不应触发粘贴")
        XCTAssertTrue(viewModel.shouldShowTextOnlyHint, "应显示'仅支持文本粘贴'提示")
    }

    // MARK: - TC-F1.9-11-02 双击文件路径类型行显示提示不粘贴

    @MainActor
    func testHandleDoubleClick_OnFilePathRow_DoesNotPaste_AndShowsHint()
    {
        let filePathClip = ClipItem.makeFilePath(
            [URL(fileURLWithPath: "/tmp/test.txt")],
            contentType: .other,
            sourceApp: "com.test",
            sourceAppName: "Test"
        )
        let viewModel = QuickPasteViewModel(clips: [filePathClip])
        var pasteCalled = false
        viewModel.onPasteTriggered = { _ in pasteCalled = true }

        viewModel.handleDoubleClick(index: 0)

        XCTAssertFalse(pasteCalled, "双击文件路径行不应触发粘贴")
        XCTAssertTrue(viewModel.shouldShowTextOnlyHint, "应显示'仅支持文本粘贴'提示")
    }

    // MARK: - TC-F1.9-11-03 提示后可继续操作其他行（提示状态可清除）

    @MainActor
    func testHint_ClearsOnSelectOtherRow()
    {
        let imageClip = ClipItem.makeImage(
            Data([0x89]),
            contentType: .other,
            sourceApp: "com.test",
            sourceAppName: "Test"
        )
        let textClip = ClipItem.makeText(
            "文本",
            contentType: .other,
            sourceApp: "com.test",
            sourceAppName: "Test"
        )
        let viewModel = QuickPasteViewModel(clips: [imageClip, textClip])

        viewModel.handleDoubleClick(index: 0)
        XCTAssertTrue(viewModel.shouldShowTextOnlyHint)

        viewModel.selectIndex(1)
        XCTAssertFalse(viewModel.shouldShowTextOnlyHint, "选中其他行后提示应消失")
    }

    // MARK: - 测试辅助

    private static func makeTextClips(count: Int) -> [ClipItem]
    {
        (0..<count).map { index in
            ClipItem.makeText(
                "测试文本 \(index)",
                contentType: .other,
                sourceApp: "com.test",
                sourceAppName: "Test"
            )
        }
    }
}
