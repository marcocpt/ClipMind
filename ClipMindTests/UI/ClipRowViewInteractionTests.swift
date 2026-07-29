@testable import ClipMind
import XCTest

final class ClipRowViewInteractionTests: XCTestCase
{
    // MARK: - TC-F1.9-4-01 单击列表行高亮选中（单元层验证 isSelected 状态）

    func testClipRowView_AcceptsIsSelectedParameter_True()
    {
        let clip = ClipItem.makeText(
            "测试",
            contentType: .other,
            sourceApp: "com.test",
            sourceAppName: "Test"
        )
        let row = ClipRowView(clip: clip, isSelected: true)
        XCTAssertTrue(row.isSelected, "isSelected=true 应被接受")
    }

    func testClipRowView_AcceptsIsSelectedParameter_False_Default()
    {
        let clip = ClipItem.makeText(
            "测试",
            contentType: .other,
            sourceApp: "com.test",
            sourceAppName: "Test"
        )
        let row = ClipRowView(clip: clip)
        XCTAssertFalse(row.isSelected, "不传 isSelected 时默认 false")
    }

    // MARK: - TC-F1.9-5-01 双击触发回调（单元层验证闭包可注入）

    func testClipRowView_AcceptsOnDoubleClickClosure()
    {
        let clip = ClipItem.makeText(
            "测试",
            contentType: .other,
            sourceApp: "com.test",
            sourceAppName: "Test"
        )
        var triggered = false
        let row = ClipRowView(
            clip: clip,
            onDoubleClick: { triggered = true }
        )
        row.onDoubleClick?()
        XCTAssertTrue(triggered, "双击回调应可被触发")
    }

    // MARK: - 菜单栏 popover 兼容性：不传回调时不触发

    func testClipRowView_NoCallbacks_DoesNotCrash()
    {
        let clip = ClipItem.makeText(
            "测试",
            contentType: .other,
            sourceApp: "com.test",
            sourceAppName: "Test"
        )
        let row = ClipRowView(clip: clip)
        XCTAssertNil(row.onSingleClick, "不传 onSingleClick 时应为 nil")
        XCTAssertNil(row.onDoubleClick, "不传 onDoubleClick 时应为 nil")
        XCTAssertNil(row.onTagActivate, "不传 onTagActivate 时应为 nil")
    }

    // MARK: - TC-F1.14 标签主动作与条目主动作隔离

    func testClipRowView_AcceptsOnTagActivateClosure()
    {
        let clip = ClipItem.makeText(
            "测试",
            contentType: .other,
            sourceApp: "com.test",
            sourceAppName: "Test"
        )
        var tagTriggered = false
        var singleTriggered = false
        var doubleTriggered = false
        let row = ClipRowView(
            clip: clip,
            onSingleClick: { singleTriggered = true },
            onDoubleClick: { doubleTriggered = true },
            onTagActivate: { tagTriggered = true }
        )
        row.onTagActivate?()
        XCTAssertTrue(tagTriggered, "标签回调应可被触发")
        XCTAssertFalse(singleTriggered, "标签触发不应调用单击回调")
        XCTAssertFalse(doubleTriggered, "标签触发不应调用双击回调")
    }

    func testClipRowView_SingleClickDoesNotTriggerTagActivate()
    {
        let clip = ClipItem.makeText(
            "测试",
            contentType: .other,
            sourceApp: "com.test",
            sourceAppName: "Test"
        )
        var tagTriggered = false
        var singleTriggered = false
        let row = ClipRowView(
            clip: clip,
            onSingleClick: { singleTriggered = true },
            onTagActivate: { tagTriggered = true }
        )
        row.onSingleClick?()
        XCTAssertTrue(singleTriggered, "单击回调应可被触发")
        XCTAssertFalse(tagTriggered, "单击触发不应调用标签回调")
    }

    func testClipRowView_DoubleClickDoesNotTriggerTagActivate()
    {
        let clip = ClipItem.makeText(
            "测试",
            contentType: .other,
            sourceApp: "com.test",
            sourceAppName: "Test"
        )
        var tagTriggered = false
        var doubleTriggered = false
        let row = ClipRowView(
            clip: clip,
            onDoubleClick: { doubleTriggered = true },
            onTagActivate: { tagTriggered = true }
        )
        row.onDoubleClick?()
        XCTAssertTrue(doubleTriggered, "双击回调应可被触发")
        XCTAssertFalse(tagTriggered, "双击触发不应调用标签回调")
    }
}
