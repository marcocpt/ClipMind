import ApplicationServices
import UserNotifications
import XCTest

@testable import ClipMind

/// 辅助功能权限请求器测试
///
/// 用户反馈点击「打开系统设置」按钮后，系统设置面板打开但 ClipMind 未被自动加入辅助功能权限列表。
/// 期望行为：调用 `AXIsProcessTrustedWithOptions` 并传入 `kAXTrustedCheckOptionPrompt: true`，
/// 触发系统级 TCC 提示对话框，自动把当前 app 加入权限列表。
final class PermissionRequesterTests: XCTestCase {
    private var originalCheck: ((Bool) -> Bool)?
    private var originalOpenSettings: (() -> Void)?
    private var originalStatusProvider: NotificationStatusProvider?
    private var originalRequester: NotificationAuthorizationRequesterType?
    private var originalURLHandler: (() -> Void)?

    override func setUp() {
        super.setUp()
        originalCheck = PermissionRequester.axTrustedCheck
        originalOpenSettings = PermissionRequester.openSystemSettings
        originalStatusProvider = PermissionRequester.notificationAuthorizationStatusProvider
        originalRequester = PermissionRequester.notificationAuthorizationRequester
        originalURLHandler = PermissionRequester.notificationSettingsURLHandler
    }

    override func tearDown() {
        if let original = originalCheck {
            PermissionRequester.axTrustedCheck = original
        }
        if let original = originalOpenSettings {
            PermissionRequester.openSystemSettings = original
        }
        if let original = originalStatusProvider {
            PermissionRequester.notificationAuthorizationStatusProvider = original
        }
        if let original = originalRequester {
            PermissionRequester.notificationAuthorizationRequester = original
        }
        if let original = originalURLHandler {
            PermissionRequester.notificationSettingsURLHandler = original
        }
        originalCheck = nil
        originalOpenSettings = nil
        originalStatusProvider = nil
        originalRequester = nil
        originalURLHandler = nil
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

    /// 点击「打开系统设置」时，应先打开系统设置面板，再触发 TCC 提示
    ///
    /// 根因：原实现先调用 `AXIsProcessTrustedWithOptions(prompt=true)`（异步触发 TCC 提示对话框），
    /// 再立即调用 `NSWorkspace.shared.open(url)` 打开系统设置面板。系统设置抢占焦点后，
    /// TCC 提示对话框被覆盖或显示在后面，用户看不到，误以为 app 未加入列表。
    ///
    /// 修复后：先打开系统设置面板，再触发 TCC 提示对话框，让对话框显示在系统设置之上。
    func testOpenAccessibilitySettingsAndPromptOpensSettingsBeforeRequest() {
        var callOrder: [String] = []
        PermissionRequester.axTrustedCheck = { _ in
            callOrder.append("requestAccessibility")
            return false
        }
        PermissionRequester.openSystemSettings = {
            callOrder.append("openSystemSettings")
        }

        PermissionRequester.openAccessibilitySettingsAndPrompt()

        XCTAssertEqual(
            callOrder,
            ["openSystemSettings", "requestAccessibility"],
            "应先打开系统设置面板，再触发 TCC 提示，让对话框显示在系统设置之上"
        )
    }

    // MARK: - 通知权限请求测试

    /// 通知权限状态为 .notDetermined 时，应调用 requestAuthorization 弹出系统对话框
    ///
    /// 回归保护：确保首次请求通知权限时走 requestAuthorization 路径，
    /// 而非错误地打开系统设置页面。
    func testRequestNotificationWhenNotDeterminedCallsAuthorization() {
        var capturedOptions: UNAuthorizationOptions?
        var openedSettings = false

        PermissionRequester.notificationAuthorizationStatusProvider = { completion in
            completion(.notDetermined)
        }
        PermissionRequester.notificationAuthorizationRequester = { options, completion in
            capturedOptions = options
            completion(true, nil)
        }
        PermissionRequester.notificationSettingsURLHandler = {
            openedSettings = true
        }

        let expectation = XCTestExpectation(description: "requestNotification completion 被调用")
        PermissionRequester.requestNotification {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2)

        XCTAssertEqual(
            capturedOptions,
            [.alert, .sound],
            "notDetermined 状态应请求 alert+sound 权限"
        )
        XCTAssertFalse(
            openedSettings,
            "notDetermined 状态不应打开系统设置页面"
        )
    }

    /// 通知权限状态为 .denied 时，应打开系统设置通知页面引导用户手动开启
    ///
    /// 核心 bug 修复：用户曾拒绝通知权限后，macOS 不再弹出授权对话框，
    /// 必须引导用户去系统设置手动开启，否则点击按钮无任何反应。
    func testRequestNotificationWhenDeniedOpensSystemSettings() {
        var requestedAuthorization = false
        var openedSettings = false

        PermissionRequester.notificationAuthorizationStatusProvider = { completion in
            completion(.denied)
        }
        PermissionRequester.notificationAuthorizationRequester = { _, completion in
            requestedAuthorization = true
            completion(false, nil)
        }
        PermissionRequester.notificationSettingsURLHandler = {
            openedSettings = true
        }

        let expectation = XCTestExpectation(description: "requestNotification completion 被调用")
        PermissionRequester.requestNotification {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2)

        XCTAssertTrue(
            openedSettings,
            "denied 状态应打开系统设置通知页面引导用户手动开启"
        )
        XCTAssertFalse(
            requestedAuthorization,
            "denied 状态不应再调用 requestAuthorization（系统不会弹窗）"
        )
    }

    /// 通知权限状态为 .authorized 时，不应执行任何操作
    ///
    /// 回归保护：已授权时不应重复请求或打开系统设置。
    func testRequestNotificationWhenAuthorizedDoesNothing() {
        var requestedAuthorization = false
        var openedSettings = false

        PermissionRequester.notificationAuthorizationStatusProvider = { completion in
            completion(.authorized)
        }
        PermissionRequester.notificationAuthorizationRequester = { _, completion in
            requestedAuthorization = true
            completion(true, nil)
        }
        PermissionRequester.notificationSettingsURLHandler = {
            openedSettings = true
        }

        let expectation = XCTestExpectation(description: "requestNotification completion 被调用")
        PermissionRequester.requestNotification {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2)

        XCTAssertFalse(
            requestedAuthorization,
            "authorized 状态不应再调用 requestAuthorization"
        )
        XCTAssertFalse(
            openedSettings,
            "authorized 状态不应打开系统设置页面"
        )
    }
}
