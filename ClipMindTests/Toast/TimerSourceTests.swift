import XCTest

@testable import ClipMind

final class TimerSourceTests: XCTestCase
{
    func testMainTimerSourceFiresAfterDuration()
    {
        let expectation = XCTestExpectation(description: "MainTimerSource fires")
        let timer = MainTimerSource()
        let handle = timer.schedule(duration: 0.1) {
            expectation.fulfill()
        }
        // schedule 返回非 optional TimerHandle，无需 XCTAssertNotNil
        _ = handle
        wait(for: [expectation], timeout: 1.0)
    }

    func testMainTimerSourceCancelPreventsFire()
    {
        let expectation = XCTestExpectation(description: "should not fire")
        expectation.isInverted = true

        let timer = MainTimerSource()
        let handle = timer.schedule(duration: 0.1) {
            expectation.fulfill()
        }
        handle.cancel()

        wait(for: [expectation], timeout: 0.5)
    }

    func testVirtualTimerSourceDoesNotFireUntilAdvanced()
    {
        let timer = VirtualTimerSource()
        var fired = false
        _ = timer.schedule(duration: 2.0) {
            fired = true
        }

        // 推进 1 秒，不应触发
        timer.advance(by: 1.0)
        XCTAssertFalse(fired, "未到 2 秒不应触发")

        // 再推进 1 秒，应触发
        timer.advance(by: 1.0)
        XCTAssertTrue(fired, "到达 2 秒应触发")
    }

    func testVirtualTimerSourceCancelPreventsFire()
    {
        let timer = VirtualTimerSource()
        var fired = false
        let handle = timer.schedule(duration: 2.0) {
            fired = true
        }
        handle.cancel()
        timer.advance(by: 3.0)
        XCTAssertFalse(fired, "cancel 后即使推进也不应触发")
    }

    func testVirtualTimerSourceMultipleTimersFireInOrder()
    {
        let timer = VirtualTimerSource()
        var sequence: [String] = []
        _ = timer.schedule(duration: 1.0) { sequence.append("first") }
        _ = timer.schedule(duration: 2.0) { sequence.append("second") }
        _ = timer.schedule(duration: 0.5) { sequence.append("third") }

        timer.advance(by: 0.5)
        XCTAssertEqual(sequence, ["third"])
        timer.advance(by: 0.5)
        XCTAssertEqual(sequence, ["third", "first"])
        timer.advance(by: 1.0)
        XCTAssertEqual(sequence, ["third", "first", "second"])
    }
}
