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
}
