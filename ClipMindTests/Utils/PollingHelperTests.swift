import XCTest

@testable import ClipMind

final class PollingHelperTests: XCTestCase
{
    // MARK: - TC-UT-61：条件立即满足时返回 true

    func testConditionMetImmediately() throws
    {
        let result = PollingHelper.waitUntil(interval: 0.01, timeout: 1.0) { true }
        XCTAssertTrue(result)
    }

    // MARK: - TC-UT-62：条件从未满足时超时返回 false

    func testTimeoutReturnsFalse() throws
    {
        let start = Date()
        let result = PollingHelper.waitUntil(interval: 0.01, timeout: 0.1) { false }
        let elapsed = Date().timeIntervalSince(start)

        XCTAssertFalse(result)
        XCTAssertGreaterThanOrEqual(elapsed, 0.1, "应等待至少 timeout 时长")
        XCTAssertLessThan(elapsed, 0.5, "不应远超 timeout 时长")
    }

    // MARK: - TC-UT-63：条件延迟满足时返回 true

    func testConditionMetAfterDelay() throws
    {
        var counter = 0
        let result = PollingHelper.waitUntil(interval: 0.01, timeout: 1.0) {
            counter += 1
            return counter >= 3
        }
        XCTAssertTrue(result)
        XCTAssertGreaterThanOrEqual(counter, 3)
    }

    // MARK: - TC-UT-64：默认参数（10ms 间隔，3s 超时）

    func testDefaultParameters() throws
    {
        let result = PollingHelper.waitUntil { true }
        XCTAssertTrue(result)
    }
}
