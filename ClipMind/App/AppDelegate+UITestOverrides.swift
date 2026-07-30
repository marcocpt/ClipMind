import AppKit
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
        // F1.14：--UITEST_QUICK_PASTE_PANEL 也需要 hasCompletedOnboarding=true，
        // 否则 configureActivationPolicy 走 onboarding 分支，不创建 quick paste panel。
        if CommandLine.arguments.contains("--UITEST_QUICK_PASTE_PANEL")
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
        // F1.14：标签 UI 测试夹具与 FailOnce 参数由 TagUITestSupport 在
        // CLIPMIND_DEV 构建中处理，生产构建为空实现。
        applyTagUITestOverrides()
    }

    /// F1.14 标签 UI 测试参数覆盖。
    ///
    /// `CLIPMIND_DEV` 构建中由 `TagUITestSupport` 解析启动参数并在
    /// `TagBackendFactory.makeDefault()` 中注入夹具；生产构建为空实现。
    private func applyTagUITestOverrides()
    {
        #if CLIPMIND_DEV
        // TagUITestSupport 通过 CommandLine.arguments 静态属性解析参数，
        // 实际夹具注入在 TagBackendFactory.makeDefault() 中执行。
        // 此方法保留为扩展点，供未来需要在 AppDelegate 生命周期早期
        // 预处理的标签 UITest 参数使用。
        if TagUITestSupport.shouldSeedTagFixture
            || TagUITestSupport.shouldSeedLimitFixture
            || TagUITestSupport.shouldSeedEmptyClip
        {
            LogCategory.app.info("F1.14 tag UITest fixture requested")
        }
        #endif
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

    /// F1.14：UITEST 模式下定位主窗口。
    ///
    /// SwiftUI `WindowGroup` 会恢复上次保存的窗口位置，可能离屏（例如之前的测试
    /// 或手动操作把窗口拖到屏幕外），导致 XCUITest 无法点击标签 pill 等元素。
    ///
    /// 在 `applicationDidFinishLaunching` 返回后延迟执行：SwiftUI 异步创建主窗口，
    /// `DispatchQueue.main.asyncAfter` 确保窗口已存在。通过窗口类名
    /// （`AppKitWindow`）识别 SwiftUI 主窗口，而非依赖标题（SwiftUI 窗口标题
    /// 在某些时机可能为空）。
    ///
    /// 若启动了 `--UITEST_QUICK_PASTE_PANEL`，隐藏主窗口：
    /// 1. 主窗口与面板存在同 ID 的标签 pill，隐藏后 XCUITest 只能命中面板 pill；
    /// 2. 不调用 `makeKeyAndOrderFront`，避免抢焦点导致快速粘贴面板 `didResignKey` 关闭。
    ///
    /// `--UITEST_KEEP_MAIN_WINDOW_VISIBLE` 时不隐藏主窗口，供
    /// `testPanelCloses_OnResignFocus` 等需要点击主窗口触发失焦的测试使用。
    @MainActor
    func centerMainWindowForUITest()
    {
        let hasQuickPastePanel = CommandLine.arguments.contains("--UITEST_QUICK_PASTE_PANEL")
        let keepMainWindowVisible = CommandLine.arguments.contains("--UITEST_KEEP_MAIN_WINDOW_VISIBLE")
        // 使用重试循环查找主窗口：SwiftUI WindowGroup 异步创建主窗口，
        // 创建时机不确定（可能在 0.5s 后才完成），固定延迟可能导致漏找。
        // 每 0.2s 重试一次，最多 5s（25 次）。
        centerMainWindowRetry(
            hasQuickPastePanel: hasQuickPastePanel,
            keepMainWindowVisible: keepMainWindowVisible,
            remainingAttempts: 25
        )
    }

    /// 重试查找并定位 SwiftUI 主窗口。
    private func centerMainWindowRetry(
        hasQuickPastePanel: Bool,
        keepMainWindowVisible: Bool,
        remainingAttempts: Int
    )
    {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2)
        {
            let mainWindows = NSApp.windows.filter
            { $0.className.contains("AppKitWindow") }
            if mainWindows.isEmpty && remainingAttempts > 1
            {
                self.centerMainWindowRetry(
                    hasQuickPastePanel: hasQuickPastePanel,
                    keepMainWindowVisible: keepMainWindowVisible,
                    remainingAttempts: remainingAttempts - 1
                )
                return
            }
            for window in mainWindows
            {
                if hasQuickPastePanel && !keepMainWindowVisible
                {
                    // 隐藏主窗口：避免同 ID pill 干扰面板测试。
                    window.setIsVisible(false)
                } else if hasQuickPastePanel && keepMainWindowVisible
                {
                    // --UITEST_KEEP_MAIN_WINDOW_VISIBLE 时保留主窗口可见。
                    // 用 orderFrontRegardless 而非 makeKeyAndOrderFront：
                    // 前者不会抢夺面板 key 状态，避免触发 didResignKey 关闭面板。
                    window.setFrameOrigin(NSPoint(x: 100, y: 100))
                    window.orderFrontRegardless()
                } else
                {
                    window.setFrameOrigin(NSPoint(x: 100, y: 100))
                    window.makeKeyAndOrderFront(nil)
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
        }
    }
}
