import AppKit
import XCTest

@testable import ClipMind

final class ToastWindowManagerTests: XCTestCase
{
    private var manager: ToastWindowManager!

    override func setUp()
    {
        super.setUp()
        manager = ToastWindowManager()
    }

    override func tearDown()
    {
        manager?.hide(completion: nil)
        manager = nil
        super.tearDown()
    }

    func testInitialStateIsNotCreated()
    {
        XCTAssertFalse(manager.isWindowVisible, "初始状态窗口不可见")
    }

    func testShowCreatesWindowAndCallsDidAppear()
    {
        let expectation = XCTestExpectation(description: "onDidAppear called")
        manager.onDidAppear = { expectation.fulfill() }

        manager.show(fileName: "test.md")

        wait(for: [expectation], timeout: 1.0)
        XCTAssertTrue(manager.isWindowVisible, "show 后窗口可见")
    }

    func testHideCallsDidHideAndReleasesWindow()
    {
        let didAppear = XCTestExpectation(description: "appeared")
        manager.onDidAppear = { didAppear.fulfill() }
        manager.show(fileName: "test.md")
        wait(for: [didAppear], timeout: 1.0)

        let didHide = XCTestExpectation(description: "hidden")
        manager.onDidHide = { didHide.fulfill() }
        manager.hide(completion: nil)

        wait(for: [didHide], timeout: 1.0)
        XCTAssertFalse(manager.isWindowVisible, "hide 后窗口不可见")
    }

    func testCloseImmediatelyReleasesWindowWithoutAnimation()
    {
        let didAppear = XCTestExpectation(description: "appeared")
        manager.onDidAppear = { didAppear.fulfill() }
        manager.show(fileName: "a.md")
        wait(for: [didAppear], timeout: 1.0)

        let didClose = XCTestExpectation(description: "closed immediately")
        manager.onDidCloseImmediately = { didClose.fulfill() }
        manager.closeImmediately()

        wait(for: [didClose], timeout: 1.0)
        XCTAssertFalse(manager.isWindowVisible, "closeImmediately 后窗口不可见")
    }

    func testWindowPositionedAtTopCenterOfMainScreen()
    {
        let didAppear = XCTestExpectation(description: "appeared")
        manager.onDidAppear = { didAppear.fulfill() }
        manager.show(fileName: "test.md")
        wait(for: [didAppear], timeout: 1.0)

        guard let window = manager.currentWindowForTesting else
        {
            return XCTFail("window should exist after show")
        }

        guard let screen = NSScreen.main else
        {
            return XCTFail("NSScreen.main should exist in test env")
        }

        let visibleFrame = screen.visibleFrame
        let windowFrame = window.frame

        // 水平居中（容差 ±5pt）
        let screenCenterX = visibleFrame.midX
        let windowCenterX = windowFrame.midX
        XCTAssertEqual(windowCenterX, screenCenterX, accuracy: 5, "窗口应水平居中")

        // 垂直位于屏幕顶部 16-32pt 范围内（视觉原型 v1.2：距顶部 24px）
        let topInset = visibleFrame.maxY - windowFrame.maxY
        XCTAssertGreaterThanOrEqual(topInset, 16, "距顶部应 ≥ 16pt")
        XCTAssertLessThanOrEqual(topInset, 32, "距顶部应 ≤ 32pt")
    }
}
