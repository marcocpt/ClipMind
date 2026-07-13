import SwiftUI

@main
struct ClipMindApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            MainWindow()
        }
        .defaultSize(width: 900, height: 600)

        Settings {
            SettingsView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // UITEST_RESET_SETTINGS: 重置隐私相关 UserDefaults，确保测试间状态隔离
        if CommandLine.arguments.contains("--UITEST_RESET_SETTINGS") {
            let keys = ["sensitiveDetectionEnabled", "autoCleanupEnabled", "cleanupDays"]
            for key in keys {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        if CommandLine.arguments.contains("--UITEST_SHOW_MAIN_WINDOW") {
            NSApp.setActivationPolicy(.regular)
        } else {
            NSApp.setActivationPolicy(.accessory)
        }
        statusItemController = StatusItemController()
        statusItemController?.setup()
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
