import SwiftUI

@main
struct ClipMindApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("hasCompletedOnboarding")
    var hasCompletedOnboarding = false

    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    MainWindow()
                        .frame(minWidth: 900, minHeight: 600)
                } else {
                    OnboardingView()
                        .frame(width: 560, height: 480)
                }
            }
            .id(hasCompletedOnboarding)
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
        applyUITestOverrides()
        configureActivationPolicy()
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

    /// 应用 UI 测试启动参数覆盖
    private func applyUITestOverrides() {
        if CommandLine.arguments.contains("--UITEST_RESET_ONBOARDING") {
            let bundleId = Bundle.main.bundleIdentifier ?? "com.clipmind.app"
            UserDefaults.standard.removePersistentDomain(forName: bundleId)
            UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
            UserDefaults.standard.synchronize()
        }
        if CommandLine.arguments.contains("--UITEST_SHOW_MAIN_WINDOW") {
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
            UserDefaults.standard.synchronize()
        }
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
            UserDefaults.standard.synchronize()
        }
    }

    /// 根据引导状态配置激活策略和服务
    private func configureActivationPolicy() {
        let completed = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        LogCategory.app.info(
            "Launch: hasCompletedOnboarding=\(completed), "
            + "args=\(CommandLine.arguments.filter { $0.hasPrefix("--UITEST") })"
        )
        if completed {
            if CommandLine.arguments.contains("--UITEST_SHOW_MAIN_WINDOW") {
                NSApp.setActivationPolicy(.regular)
            } else {
                NSApp.setActivationPolicy(.accessory)
            }
            statusItemController = StatusItemController()
            statusItemController?.setup()
            setupCleanupService()
        } else {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
        }
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
