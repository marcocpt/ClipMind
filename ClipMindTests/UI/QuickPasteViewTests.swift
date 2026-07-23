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
