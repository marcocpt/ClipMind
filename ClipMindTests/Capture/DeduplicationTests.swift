@testable import ClipMind
import XCTest

final class DeduplicationTests: XCTestCase {
    private var deduplicator: Deduplicator!

    override func setUpWithError() throws {
        deduplicator = Deduplicator()
    }

    override func tearDownWithError() throws {
        deduplicator = nil
    }

    // MARK: - 首次内容

    func testFirstContentNotDuplicate() throws {
        let result = deduplicator.isDuplicate(.text("hello"))
        XCTAssertFalse(result, "首次内容不应判定为重复")
    }

    // MARK: - 文本去重

    func testSameTextContentDuplicate() throws {
        deduplicator.updateLastContent(.text("hello"))
        let result = deduplicator.isDuplicate(.text("hello"))
        XCTAssertTrue(result, "连续相同文本应判定为重复")
    }

    func testDifferentTextContentNotDuplicate() throws {
        deduplicator.updateLastContent(.text("hello"))
        let result = deduplicator.isDuplicate(.text("world"))
        XCTAssertFalse(result, "不同文本不应判定为重复")
    }

    // MARK: - 图片去重

    func testSameImageContentDuplicate() throws {
        let imageData = Data([0x89, 0x50, 0x4E, 0x47])
        deduplicator.updateLastContent(.image(imageData))
        let result = deduplicator.isDuplicate(.image(imageData))
        XCTAssertTrue(result, "连续相同图片应判定为重复")
    }

    func testDifferentImageContentNotDuplicate() throws {
        deduplicator.updateLastContent(.image(Data([0x89, 0x50])))
        let result = deduplicator.isDuplicate(.image(Data([0xFF, 0xD8])))
        XCTAssertFalse(result, "不同图片不应判定为重复")
    }

    // MARK: - 文件路径去重

    func testSameFilePathContentDuplicate() throws {
        let urls = [URL(fileURLWithPath: "/tmp/file1.txt")]
        deduplicator.updateLastContent(.filePath(urls))
        let result = deduplicator.isDuplicate(.filePath(urls))
        XCTAssertTrue(result, "连续相同文件路径应判定为重复")
    }

    // MARK: - 类型切换

    func testTextToImageNotDuplicate() throws {
        deduplicator.updateLastContent(.text("hello"))
        let result = deduplicator.isDuplicate(.image(Data([0x89])))
        XCTAssertFalse(result, "从文本切换到图片不应判定为重复")
    }

    // MARK: - 更新后判断

    func testUpdateLastContent() throws {
        deduplicator.updateLastContent(.text("first"))
        XCTAssertFalse(deduplicator.isDuplicate(.text("second")), "不同内容不应重复")

        deduplicator.updateLastContent(.text("second"))
        XCTAssertTrue(deduplicator.isDuplicate(.text("second")), "更新后相同内容应重复")
    }
}
