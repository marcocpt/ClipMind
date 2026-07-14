import AppKit
import ApplicationServices
import Foundation
import UserNotifications

/// 通知权限状态获取闭包类型
typealias NotificationStatusProvider = (@escaping (UNAuthorizationStatus) -> Void) -> Void

/// 通知权限请求闭包类型
typealias NotificationAuthorizationRequesterType = (
    UNAuthorizationOptions,
    @escaping (Bool, Error?) -> Void
) -> Void

/// 权限请求器
///
/// 封装系统 TCC 权限请求逻辑，便于在 UI 层调用与测试中注入 mock。
enum PermissionRequester {
    /// 可注入的辅助功能权限检查闭包
    ///
    /// 默认实现调用 `AXIsProcessTrustedWithOptions`，传入 prompt 选项。
    /// 测试中可替换为 mock 闭包以验证调用参数。
    ///
    /// 实现说明：使用字符串字面量 `"AXTrustedCheckOptionPrompt"` 而非全局常量
    /// `kAXTrustedCheckOptionPrompt`，避免在 Hardened Runtime + 签名 app 上下文中
    /// 因 dyld 加载时序问题导致全局 CFString 常量为 NULL，进而触发
    /// `CFGetTypeID(nil)` 解引用偏移 0x8 的 EXC_BAD_ACCESS 崩溃。
    static var axTrustedCheck: (_ prompt: Bool) -> Bool = { prompt in
        let options: NSDictionary = [
            "AXTrustedCheckOptionPrompt" as NSString: NSNumber(value: prompt)
        ]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    /// 请求辅助功能权限
    ///
    /// 调用 `AXIsProcessTrustedWithOptions` 并传入 prompt=true，
    /// 触发系统级 TCC 提示对话框，自动把当前 app 加入辅助功能权限列表。
    /// - Returns: 当前是否已授权
    @discardableResult
    static func requestAccessibility() -> Bool {
        let granted = axTrustedCheck(true)
        LogCategory.app.info("请求辅助功能权限（TCC 提示），当前授权状态: \(granted)")
        return granted
    }

    /// 可注入的通知权限状态获取闭包
    ///
    /// 默认实现调用 `UNUserNotificationCenter.getNotificationSettings` 并返回 `authorizationStatus`。
    /// 测试中可替换为 mock 闭包以验证分支逻辑。
    static var notificationAuthorizationStatusProvider: NotificationStatusProvider = { completion in
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            completion(settings.authorizationStatus)
        }
    }

    /// 可注入的通知权限请求闭包
    ///
    /// 默认实现调用 `UNUserNotificationCenter.requestAuthorization`。
    /// 测试中可替换为 mock 闭包以验证调用参数。
    static var notificationAuthorizationRequester: NotificationAuthorizationRequesterType = { options, completion in
        UNUserNotificationCenter.current().requestAuthorization(
            options: options,
            completionHandler: completion
        )
    }

    /// 可注入的打开系统设置通知页面闭包
    ///
    /// 默认实现通过 `x-apple.systempreferences:` URL scheme 打开系统设置的通知面板。
    /// 测试中可替换为 mock 闭包以验证是否被调用。
    static var notificationSettingsURLHandler: () -> Void = {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
            NSWorkspace.shared.open(url)
        }
    }

    /// 请求通知权限
    ///
    /// 根据当前 `authorizationStatus` 分支处理：
    /// - `.notDetermined`：调用 `requestAuthorization` 弹出系统授权对话框
    /// - `.denied`：打开系统设置通知页面，引导用户手动开启（系统不再弹对话框）
    /// - `.authorized` / `.provisional` / `.ephemeral`：不执行操作
    /// - Parameter completion: 完成回调，保证在主线程执行
    static func requestNotification(completion: @escaping () -> Void) {
        notificationAuthorizationStatusProvider { status in
            switch status {
            case .notDetermined:
                LogCategory.app.info("通知权限未决定，请求授权（弹出系统对话框）")
                notificationAuthorizationRequester([.alert, .sound]) { _, _ in
                    DispatchQueue.main.async { completion() }
                }
            case .denied:
                LogCategory.app.info("通知权限已被拒绝，打开系统设置通知页面引导用户手动开启")
                notificationSettingsURLHandler()
                DispatchQueue.main.async { completion() }
            case .authorized, .provisional, .ephemeral:
                LogCategory.app.info("通知权限已授权，无需操作")
                DispatchQueue.main.async { completion() }
            @unknown default:
                LogCategory.app.warning("未知的通知授权状态: \(status.rawValue)")
                DispatchQueue.main.async { completion() }
            }
        }
    }
}
