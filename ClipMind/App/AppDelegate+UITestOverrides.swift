import Foundation

// F1.11 合并修复：从 ClipMindApp.swift 提取 UITest 启动参数处理逻辑到独立文件，
// 缓解 AppDelegate type_body_length 违规（合并后 306 > 300）。
// 方法保持 private 访问级别，通过同文件 extension 访问。

extension AppDelegate
{
    /// 处理 Toast UI 测试触发
    func handleToastUITestTriggerIfNeeded()
    {
        ToastUITestLauncher.launchIfNeeded()
    }

    /// 应用通用启动参数重置（非 UITEST 专用）
    ///
    /// 在 `applicationWillFinishLaunching` 中调用，早于 SwiftUI 读取 `@AppStorage`，
    /// 确保重置后 SwiftUI 直接渲染正确视图，避免先渲染 MainWindow 再切换的时序问题。
    func applyOnboardingResetIfNeeded()
    {
        if CommandLine.arguments.contains("--reset-onboarding")
        {
            UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
            LogCategory.app.info("已通过 --reset-onboarding 重置首启引导标志位")
        }
        // --UITEST_SHOW_MAIN_WINDOW 必须在 SwiftUI 读取 @AppStorage 之前设置，
        // 否则 SwiftUI 先渲染 OnboardingView 再切换到 MainWindow。
        if CommandLine.arguments.contains("--UITEST_SHOW_MAIN_WINDOW")
        {
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        }
        UserDefaults.standard.synchronize()
    }

    /// 应用 UI 测试启动参数覆盖
    func applyUITestOverrides()
    {
        applyOnboardingUITestOverrides()
        applySettingsUITestOverrides()
        applyHotkeyUITestOverrides()
    }

    /// 应用 onboarding 相关 UITest 启动参数
    private func applyOnboardingUITestOverrides()
    {
        if CommandLine.arguments.contains("--UITEST_RESET_ONBOARDING")
        {
            let bundleId = Bundle.main.bundleIdentifier ?? "com.clipmind.app"
            UserDefaults.standard.removePersistentDomain(forName: bundleId)
            UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
            UserDefaults.standard.synchronize()
        }
        if CommandLine.arguments.contains("--UITEST_SHOW_MAIN_WINDOW")
        {
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
            UserDefaults.standard.synchronize()
        }
    }

    /// 应用设置相关 UITest 启动参数（含 F2.1 自动保存）
    private func applySettingsUITestOverrides()
    {
        if CommandLine.arguments.contains("--UITEST_RESET_SETTINGS")
        {
            let keys = [
                "sensitiveDetectionEnabled",
                "autoCleanupEnabled",
                "cleanupDays",
                "launchAtLogin",
                "hotkey",
                BlacklistService.storageKey
            ]
            for key in keys
            {
                UserDefaults.standard.removeObject(forKey: key)
            }
            UserDefaults.standard.synchronize()
        }
        if CommandLine.arguments.contains("--UITEST_RESET_AUTOSAVE_SETTINGS")
        {
            Self.resetAutoSaveSettings(in: UserDefaults.standard)
            LogCategory.app.logger.info("已通过 --UITEST_RESET_AUTOSAVE_SETTINGS 重置 F2.1 配置")
        }
        if CommandLine.arguments.contains("--UITEST_ENABLE_AUTOSAVE")
        {
            let store = AutoSaveSettingsStore()
            var settings = store.load()
            settings.isEnabled = true
            store.save(settings)
            LogCategory.app.logger.info("已通过 --UITEST_ENABLE_AUTOSAVE 启用 F2.1 总开关")
        }
    }

    /// 应用快捷键相关 UITest 启动参数
    private func applyHotkeyUITestOverrides()
    {
        if CommandLine.arguments.contains("--UITEST_LEGACY_HOTKEY")
        {
            UserDefaults.standard.set("cmd+shift+v", forKey: "hotkey")
            UserDefaults.standard.synchronize()
            LogCategory.app.logger.info("已通过 --UITEST_LEGACY_HOTKEY 注入老用户旧默认快捷键")
        }
        if CommandLine.arguments.contains("--UITEST_CUSTOM_HOTKEY")
        {
            UserDefaults.standard.set("ctrl+opt+a", forKey: "hotkey")
            UserDefaults.standard.synchronize()
            LogCategory.app.logger.info("已通过 --UITEST_CUSTOM_HOTKEY 注入自定义快捷键")
        }
    }
}
