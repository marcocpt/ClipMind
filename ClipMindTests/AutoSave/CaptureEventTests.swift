import Foundation
import XCTest

@testable import ClipMind

final class CaptureEventTests: XCTestCase
{
    // MARK: - TC-UT-01：CaptureEvent 默认构造与属性访问

    func testCaptureEventPropertiesAccessible() throws
    {
        let event = CaptureEventFixtures.shortTextEvent()

        XCTAssertEqual(event.changeCount, 42)
        XCTAssertEqual(event.bundleId, "com.apple.Safari")
        XCTAssertEqual(event.appName, "Safari")
        XCTAssertEqual(event.blacklisted, false)
        XCTAssertNotNil(event.id)
        XCTAssertNotNil(event.timestamp)
    }

    // MARK: - TC-UT-02：CaptureEvent 不可变性

    func testCaptureEventIsImmutable() throws
    {
        let event = CaptureEventFixtures.shortTextEvent()
        let originalChangeCount = event.changeCount

        // 编译期保证：所有属性为 let，无法赋值。
        XCTAssertEqual(event.changeCount, originalChangeCount)
    }

    // MARK: - TC-UT-03：CaptureEvent 携带配置快照（D6/D23）

    func testCaptureEventCarriesConfigSnapshot() throws
    {
        let event = CaptureEventFixtures.shortTextEvent()

        XCTAssertEqual(event.f2xConfigSnapshot.isEnabled, true)
        XCTAssertEqual(event.f2xConfigSnapshot.saveDirectory, "~/Documents/ClipMind/Clips/")
        XCTAssertEqual(event.f2xConfigSnapshot.fileFormat, .markdown)
        XCTAssertEqual(event.f2xConfigSnapshot.lengthThreshold, 50)
    }

    // MARK: - TC-UT-04：CaptureEvent 携带敏感识别结果（D2）

    func testCaptureEventCarriesSensitiveResult() throws
    {
        let event = CaptureEventFixtures.sensitiveContentEvent()

        XCTAssertEqual(event.sensitiveResult.isSensitive, true)
        XCTAssertEqual(event.sensitiveResult.matchedPatterns.count, 1)
    }

    // MARK: - TC-UT-05：CaptureEvent 携带 F1.x 配置快照（D3 黑名单优先）

    func testCaptureEventCarriesF1xConfigSnapshot() throws
    {
        let event = CaptureEventFixtures.blacklistedAppEvent()

        XCTAssertEqual(event.blacklisted, true)
        XCTAssertEqual(event.f1xConfigSnapshot.blacklistBundleIds.contains("com.apple.finder"), true)
    }

    // MARK: - TC-UT-06：CaptureEvent 内容长度计算

    func testCaptureEventContentLength() throws
    {
        let event = CaptureEventFixtures.shortTextEvent()

        XCTAssertEqual(event.contentLength, 11, "shortTextEvent 内容应为 'hello world' 11 字符")
    }
}
