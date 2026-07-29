@testable import ClipMind
import XCTest

final class EditableContentAreaTests: XCTestCase
{
    // MARK: - TC: 内容编辑保留当前 tagState，不产生 .legacy 短暂状态

    func testRebuildTextPreservesTagState() throws
    {
        let originalTag = ClipTag(
            id: .user(UUID(uuidString: "00000000-0000-0000-0000-0000000000aa")!),
            name: "keep",
            color: .amber,
            source: .user
        )
        var tagState = ClipTagState.newItem(contentType: .code)
        tagState.orderedTagIDs.append(originalTag.id)

        let clip = ClipItem(
            id: UUID(),
            content: .text("original"),
            contentType: .code,
            sourceApp: "com.test",
            sourceAppName: "Test",
            timestamp: Date(),
            summary: nil,
            translation: nil,
            rewrite: nil,
            todos: nil,
            embeddings: nil,
            isSample: false,
            tagState: tagState
        )

        let rebuilt = EditableContentArea.rebuild(clip: clip, with: "modified")

        XCTAssertEqual(rebuilt?.tagState, tagState, "编辑后应保留 tagState，不产生 .legacy")
        if case .text(let text) = rebuilt?.content
        {
            XCTAssertEqual(text, "modified")
        } else {
            XCTFail("Expected text content")
        }
    }

    func testRebuildFilePathPreservesTagState() throws
    {
        let originalTag = ClipTag(
            id: .user(UUID(uuidString: "00000000-0000-0000-0000-0000000000bb")!),
            name: "filetag",
            color: .blue,
            source: .user
        )
        var tagState = ClipTagState.newItem(contentType: .other)
        tagState.orderedTagIDs.append(originalTag.id)

        let clip = ClipItem(
            id: UUID(),
            content: .filePath([URL(fileURLWithPath: "/tmp/a")]),
            contentType: .other,
            sourceApp: "com.test",
            sourceAppName: "Test",
            timestamp: Date(),
            summary: nil,
            translation: nil,
            rewrite: nil,
            todos: nil,
            embeddings: nil,
            isSample: false,
            tagState: tagState
        )

        let rebuilt = EditableContentArea.rebuild(clip: clip, with: "/tmp/b\n/tmp/c")

        XCTAssertEqual(rebuilt?.tagState, tagState, "filePath 编辑后应保留 tagState")
        if case .filePath(let urls) = rebuilt?.content
        {
            XCTAssertEqual(urls.count, 2)
            XCTAssertEqual(urls[0].path, "/tmp/b")
            XCTAssertEqual(urls[1].path, "/tmp/c")
        } else {
            XCTFail("Expected filePath content")
        }
    }

    func testRebuildImageReturnsNil() throws
    {
        let clip = ClipItem.makeImage(
            Data([0x01]),
            contentType: .other,
            sourceApp: "com.test",
            sourceAppName: "Test"
        )

        let rebuilt = EditableContentArea.rebuild(clip: clip, with: "ignored")
        XCTAssertNil(rebuilt, "图片类型不支持编辑")
    }
}
