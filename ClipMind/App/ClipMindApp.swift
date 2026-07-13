import SwiftUI

@main
struct ClipMindApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("hasCompletedOnboarding")
    var hasCompletedOnboarding = false

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                MainWindow()
                    .frame(minWidth: 900, minHeight: 600)
            } else {
                OnboardingView()
                    .frame(width: 560, height: 480)
            }
        }

        Settings {
            SettingsView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItemController: StatusItemController?
    private var cleanupService: CleanupService?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // UITEST_RESET_ONBOARDING: 重置引导状态，确保测试间状态隔离
        if CommandLine.arguments.contains("--UITEST_RESET_ONBOARDING") {
            UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
        }
        // UITEST_SHOW_MAIN_WINDOW: 跳过引导直接显示主窗口
        if CommandLine.arguments.contains("--UITEST_SHOW_MAIN_WINDOW") {
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        }
        // UITEST_RESET_SETTINGS: 重置隐私相关 UserDefaults，确保测试间状态隔离
        if CommandLine.arguments.contains("--UITEST_RESET_SETTINGS") {
            let keys = [
                "sensitiveDetectionEnabled",
                "autoCleanupEnabled",
                "cleanupDays",
                "launchAtLogin",
                "hotkey",
                BlacklistService.storageKey
            ]
            for key in keys {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }

        let hasCompletedOnboarding = UserDefaults.standard.bool(
            forKey: "hasCompletedOnboarding"
        )
        if hasCompletedOnboarding {
            // 已完成引导，使用菜单栏模式
            if CommandLine.arguments.contains("--UITEST_SHOW_MAIN_WINDOW") {
                NSApp.setActivationPolicy(.regular)
            } else {
                NSApp.setActivationPolicy(.accessory)
            }
            statusItemController = StatusItemController()
            statusItemController?.setup()

            // 接入清理服务：启动时清理一次，并启动定时清理
            setupCleanupService()
        } else {
            // 未完成引导，显示常规窗口
            NSApp.setActivationPolicy(.regular)
        }

        if CommandLine.arguments.contains("--UITEST_POPOVER_WINDOW") {
            showPopoverContentInWindow()
        }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOpenMainWindow),
            name: .openMainWindow,
            object: nil
        )
    }

    /// 初始化清理服务并启动
    private func setupCleanupService() {
        do {
            let store = try EncryptedStore()
            let settings = AppSettings()
            cleanupService = CleanupService(store: store, settings: settings)
            cleanupService?.cleanupOnLaunch()
            cleanupService?.startPeriodicCleanup()
        } catch {
            LogCategory.storage.error("清理服务初始化失败: \(error.localizedDescription)")
        }
    }

    private func showPopoverContentInWindow() {
        NSApp.setActivationPolicy(.regular)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 480),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "PopoverPreview"
        window.contentViewController = NSHostingController(rootView: PopoverView())
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func handleOpenMainWindow() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows where window.canBecomeKey {
            window.makeKeyAndOrderFront(nil)
            break
        }
    }
}
