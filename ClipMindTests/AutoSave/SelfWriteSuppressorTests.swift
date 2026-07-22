import XCTest

@testable import ClipMind

final class SelfWriteSuppressorTests: XCTestCase
{
    // MARK: - TC-UT-25：无标记时 checkAndReset 返回 false

    func testNoMarkReturnsFalse() throws
    {
        let suppressor = SelfWriteSuppressor()
        XCTAssertFalse(suppressor.checkAndReset(changeCount: 1))
    }

    // MARK: - TC-UT-26：标记后 checkAndReset 返回 true

    func testMarkThenCheckReturnsTrue() throws
    {
        let suppressor = SelfWriteSuppressor()
        suppressor.markSelfWrite(changeCount: 42)
        XCTAssertTrue(suppressor.checkAndReset(changeCount: 42))
    }

    // MARK: - TC-UT-27：checkAndReset 后标记被清除（一次性）

    func testCheckAndResetClearsMark() throws
    {
        let suppressor = SelfWriteSuppressor()
        suppressor.markSelfWrite(changeCount: 42)
        XCTAssertTrue(suppressor.checkAndReset(changeCount: 42))
        XCTAssertFalse(suppressor.checkAndReset(changeCount: 42), "标记应被清除")
    }

    // MARK: - TC-UT-28：不同 changeCount 不匹配

    func testDifferentChangeCountDoesNotMatch() throws
    {
        let suppressor = SelfWriteSuppressor()
        suppressor.markSelfWrite(changeCount: 42)
        XCTAssertFalse(suppressor.checkAndReset(changeCount: 43))
    }

    // MARK: - TC-UT-29：5 秒超时失效（D4）

    func testFiveSecondTimeout() throws
    {
        let suppressor = SelfWriteSuppressor(timeoutInterval: 0.1)
        suppressor.markSelfWrite(changeCount: 42)

        let expectation = XCTestExpectation(description: "超时后标记应失效")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2)
        {
            XCTAssertFalse(suppressor.checkAndReset(changeCount: 42), "超时后标记应失效")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }
}
