import AppKit
import ApplicationServices
import Foundation

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

    /// 可注入的「打开系统设置辅助功能面板」闭包
    ///
    /// 默认实现通过 `x-apple.systempreferences:` URL scheme 打开
    /// 「系统设置 → 隐私与安全性 → 辅助功能」面板。
    /// 测试中可替换为 mock 闭包以验证调用顺序。
    static var openSystemSettings: () -> Void = {
        guard
            let url = URL(
                string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
            )
        else {
            LogCategory.app.error("无法构造辅助功能系统设置 URL")
            return
        }
        NSWorkspace.shared.open(url)
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

    /// 打开系统设置辅助功能面板并触发 TCC 提示
    ///
    /// 调用顺序至关重要：**先**打开系统设置面板，**再**触发 TCC 提示。
    ///
    /// 原因：`AXIsProcessTrustedWithOptions(prompt=true)` 同步返回，
    /// 但 TCC 提示对话框由系统进程 tccd 异步显示。若先触发 TCC 提示再立即打开
    /// 系统设置，系统设置面板会抢占焦点，TCC 提示对话框被遮挡或显示在后面，
    /// 用户看不到，误以为 app 未加入辅助功能列表。
    ///
    /// 调整顺序后：系统设置面板先打开获得焦点，随后 TCC 提示对话框显示在
    /// 系统设置面板之上，用户能清晰看到对话框并完成授权。
    static func openAccessibilitySettingsAndPrompt() {
        openSystemSettings()
        LogCategory.app.info("已打开辅助功能系统设置面板")
        requestAccessibility()
        LogCategory.app.info("已触发 TCC 提示（显示在系统设置面板之上）")
    }
}
