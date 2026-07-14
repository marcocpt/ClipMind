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

    /// 默认 axTrustedCheck 闭包调用真实 AXIsProcessTrustedWithOptions 不崩溃
    ///
    /// 回归保护：早期版本使用 `kAXTrustedCheckOptionPrompt` 全局 CFString 常量作为 NSDictionary
    /// 字面量 key，在 Hardened Runtime + 签名 app 上下文中该常量可能因 dyld 加载时序问题为 NULL，
    /// 导致 `AXIsProcessTrustedWithOptions` 内部 `CFGetTypeID(nil)` 解引用偏移 0x8 崩溃。
    /// 修复后改用字符串字面量 `"AXTrustedCheckOptionPrompt"`，本测试验证默认闭包稳定可调用。
    ///
    /// 使用 `prompt=false` 避免触发系统 TCC 提示对话框，仍会调用真实 API 验证字典构造稳定。
    func testDefaultAxTrustedCheckDoesNotCrash() {
        // Arrange：setUp 已保存默认闭包，未注入 mock
        // Act：直接调用默认闭包（真实 AXIsProcessTrustedWithOptions，prompt=false 不弹窗）
        // 若 kAXTrustedCheckOptionPrompt 全局常量为 NULL，此处会触发 EXC_BAD_ACCESS
        let result = PermissionRequester.axTrustedCheck(false)
        // Assert：到达此断言即证明默认闭包稳定可调用而未崩溃
        XCTAssertTrue(result || !result, "默认 axTrustedCheck 闭包应稳定调用而不崩溃")
    }
}
