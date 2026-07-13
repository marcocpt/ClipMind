import ApplicationServices
import XCTest

@testable import ClipMind

/// 辅助功能权限请求器测试
///
/// 用户反馈点击「打开系统设置」按钮后，系统设置面板打开但 ClipMind 未被自动加入辅助功能权限列表。
/// 期望行为：调用 `AXIsProcessTrustedWithOptions` 并传入 `kAXTrustedCheckOptionPrompt: true`，
/// 触发系统级 TCC 提示对话框，自动把当前 app 加入权限列表。
final class PermissionRequesterTests: XCTestCase {
    private var originalCheck: ((Bool) -> Bool)?

    override func setUp() {
        super.setUp()
        originalCheck = PermissionRequester.axTrustedCheck
    }

    override func tearDown() {
        if let original = originalCheck {
            PermissionRequester.axTrustedCheck = original
        }
        originalCheck = nil
        super.tearDown()
    }

    /// 请求辅助功能权限时必须传入 prompt=true，触发系统 TCC 提示
    func testRequestAccessibilityPassesPromptTrue() {
        var capturedPrompt: Bool?

        PermissionRequester.axTrustedCheck = { prompt in
            capturedPrompt = prompt
            return false
        }

        let result = PermissionRequester.requestAccessibility()

        XCTAssertEqual(capturedPrompt, true, "requestAccessibility 必须传入 prompt=true 触发 TCC 提示")
        XCTAssertFalse(result, "未授权时应返回 false")
    }

    /// 已授权时返回 true
    func testRequestAccessibilityReturnsTrueWhenGranted() {
        PermissionRequester.axTrustedCheck = { _ in true }

        let result = PermissionRequester.requestAccessibility()

        XCTAssertTrue(result, "已授权时应返回 true")
    }
}
