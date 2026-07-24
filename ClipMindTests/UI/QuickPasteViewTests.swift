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

    // MARK: - TC-F1.9-5-01 双击文本行触发粘贴流程（按 clip 而非 index，修复搜索过滤后索引不匹配）

    /// Bug 修复：搜索过滤后 filteredClips 的 index 与 viewModel.clips 的 index 不一致，
    /// 导致 handleDoubleClick(index:) 访问错误的 clip。
    /// 新 API handleDoubleClick(clip:) 直接按 clip 查找，消除索引依赖。
    @MainActor
    func testHandleDoubleClick_ByClip_PastesCorrectClip_EvenWhenFiltered()
    {
        // 场景：clips = [imageClip, textClip]
        // 搜索 "目标" 后 filteredClips = [textClip]，filteredClips 的 index=0
        // 旧 API handleDoubleClick(index: 0) 会访问 clips[0] = imageClip（错误，显示提示不粘贴）
        // 新 API handleDoubleClick(clip: textClip) 应直接粘贴 textClip
        let imageClip = ClipItem.makeImage(
            Data([0x89, 0x50, 0x4E, 0x47]),
            contentType: .other,
            sourceApp: "com.test",
            sourceAppName: "Test"
        )
        let textClip = ClipItem.makeText(
            "目标文本",
            contentType: .other,
            sourceApp: "com.test",
            sourceAppName: "Test"
        )
        let viewModel = QuickPasteViewModel(clips: [imageClip, textClip])

        var pastedClip: ClipItem?
        viewModel.onPasteTriggered = { clip in pastedClip = clip }

        // 模拟 View 传入被双击的 clip 本身（而非 filteredClips 的 index）
        viewModel.handleDoubleClick(clip: textClip)

        XCTAssertNotNil(pastedClip, "双击文本 clip 应触发粘贴回调")
        XCTAssertEqual(pastedClip?.id, textClip.id, "应粘贴正确的 clip（textClip）而非 clips[0]（imageClip）")
        XCTAssertFalse(viewModel.shouldShowTextOnlyHint, "文本 clip 不应显示'仅支持文本粘贴'提示")
    }

    // MARK: - TC-F1.9-5-01 双击图片 clip 显示提示不粘贴（按 clip 而非 index）

    @MainActor
    func testHandleDoubleClick_ByImageClip_DoesNotPaste_AndShowsHint()
    {
        let imageClip = ClipItem.makeImage(
            Data([0x89, 0x50, 0x4E, 0x47]),
            contentType: .other,
            sourceApp: "com.test",
            sourceAppName: "Test"
        )
        let textClip = ClipItem.makeText(
            "其他文本",
            contentType: .other,
            sourceApp: "com.test",
            sourceAppName: "Test"
        )
        let viewModel = QuickPasteViewModel(clips: [textClip, imageClip])

        var pasteCalled = false
        viewModel.onPasteTriggered = { _ in pasteCalled = true }

        // 双击 imageClip（在 clips[1]，确保不是通过 index=0 访问到）
        viewModel.handleDoubleClick(clip: imageClip)

        XCTAssertFalse(pasteCalled, "双击图片 clip 不应触发粘贴")
        XCTAssertTrue(viewModel.shouldShowTextOnlyHint, "应显示'仅支持文本粘贴'提示")
    }

    // MARK: - 集成测试：双击文本行触发 onPasteTriggered（TC-F1.9-5-01 集成层）

    @MainActor
    func testDoubleClick_OnTextRow_TriggersPasteViaViewModel()
    {
        let clips = QuickPasteViewTests.makeTextClips(count: 2)
        let viewModel = QuickPasteViewModel(clips: clips)
        var pasteCount = 0
        viewModel.onPasteTriggered = { _ in pasteCount += 1 }

        // 模拟双击第一行
        viewModel.handleDoubleClick(index: 0)
        // 模拟双击第二行
        viewModel.handleDoubleClick(index: 1)

        XCTAssertEqual(pasteCount, 2, "双击两行应触发两次粘贴回调")
    }

    // MARK: - 集成测试：双击图片行后选中其他行清除提示（TC-F1.9-11-03 集成层）

    @MainActor
    func testHint_ClearsWhenSelectingOtherRow_AfterImageDoubleClick()
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
        XCTAssertFalse(viewModel.shouldShowTextOnlyHint)
        XCTAssertEqual(viewModel.selectedIndex, 1)
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
