import AppKit
import Foundation
import XCTest

@testable import ClipMind

#if CLIPMIND_DEV

/// 辅助功能服务测试（Phase 4，仅 ClipMind-Dev Scheme 编译）。
///
/// 覆盖 TC-F1.9-12-01（权限检测不缓存）、TC-F1.9-2-01/02（caret 定位 mock）。
final class AccessibilityServiceTests: XCTestCase
{
    private var originalAxTrustedCheck: ((Bool) -> Bool)?

    override func setUp()
    {
        super.setUp()
        originalAxTrustedCheck = PermissionRequester.axTrustedCheck
    }

    override func tearDown()
    {
        if let original = originalAxTrustedCheck
        {
            PermissionRequester.axTrustedCheck = original
            originalAxTrustedCheck = nil
        }
        super.tearDown()
    }

    // MARK: - TC-F1.9-12-01 权限检测不缓存（每次调用都重新检测）

    func testIsAccessibilityGranted_DoesNotCache_ChecksEveryTime()
    {
        let provider = MockAXTrustedProvider(granted: false)
        PermissionRequester.axTrustedCheck = { _ in provider.granted }

        let service = AccessibilityService()

        XCTAssertFalse(service.isAccessibilityGranted(), "首次检测应返回 false")

        provider.granted = true
        XCTAssertTrue(service.isAccessibilityGranted(), "权限状态变更后应返回 true（不缓存）")

        provider.granted = false
        XCTAssertFalse(service.isAccessibilityGranted(), "权限再次变更后应返回 false（不缓存）")
    }

    // MARK: - TC-F1.9-2-01 有权限时获取 caret 位置

    func testLocateCaret_ReturnsCaretPosition_WhenAvailable()
    {
        let service = AccessibilityService(caretProvider: MockCaretProvider(caret: NSPoint(x: 300, y: 400)))

        let caret = service.locateCaret()

        XCTAssertNotNil(caret, "有 caret 时应返回坐标")
        XCTAssertEqual(caret?.x ?? 0, 300, accuracy: 0.01)
        XCTAssertEqual(caret?.y ?? 0, 400, accuracy: 0.01)
    }

    // MARK: - TC-F1.9-2-02 前台应用无 caret 时降级到鼠标位置

    func testLocateCaret_ReturnsNil_WhenNoCaret()
    {
        let service = AccessibilityService(caretProvider: MockCaretProvider(caret: nil))

        let caret = service.locateCaret()

        XCTAssertNil(caret, "无 caret 时应返回 nil（由调用方降级到鼠标位置）")
    }

    // MARK: - 鼠标位置降级

    func testCurrentMouseLocation_ReturnsInjectedPoint()
    {
        let service = AccessibilityService(mouseProvider: MockMouseProvider(location: NSPoint(x: 500, y: 600)))

        let location = service.currentMouseLocation()

        XCTAssertEqual(location.x, 500, accuracy: 0.01)
        XCTAssertEqual(location.y, 600, accuracy: 0.01)
    }

    // MARK: - 权限检测调用 PermissionRequester.axTrustedCheck(false) 不弹 TCC

    func testIsAccessibilityGranted_CallsAXTrustedCheckWithFalsePrompt()
    {
        var capturedPrompt: Bool?
        PermissionRequester.axTrustedCheck = { prompt in
            capturedPrompt = prompt
            return false
        }

        let service = AccessibilityService()
        _ = service.isAccessibilityGranted()

        XCTAssertEqual(capturedPrompt, false, "权限检测应传入 prompt: false 不弹 TCC")
    }

    // MARK: - 测试辅助 Mock

    private final class MockAXTrustedProvider
    {
        var granted: Bool
        init(granted: Bool)
        {
            self.granted = granted
        }
    }

    private final class MockCaretProvider: CaretLocating
    {
        let caret: NSPoint?
        init(caret: NSPoint?)
        {
            self.caret = caret
        }

        func locateCaret() -> NSPoint? { caret }
    }

    private final class MockMouseProvider: MousePositionProviding
    {
        let location: NSPoint
        init(location: NSPoint)
        {
            self.location = location
        }

        func currentMouseLocation() -> NSPoint { location }
    }
}

#endif
