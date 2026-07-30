import AppKit
import SwiftUI

// MARK: - 设置窗口装配（F1.11 Phase 3）

extension AppDelegate
{
    /// F1.11 Phase 3：处理「打开设置窗口」信号。
    ///
    /// 生产环境通过 macOS 13 的 `showSettingsWindow:` 选择器触发 SwiftUI Settings 场景。
    /// UI 测试模式下（CI 环境）Settings 场景无法通过 sendAction 正常创建窗口，
    /// 复用 `MainWindow.showSettingsInStandaloneWindow` 的独立窗口路径，确保 XCUITest 能可靠定位元素。
    ///
    /// F1.11 Phase 3 修复：菜单栏应用默认 `accessory` 激活策略，直接 `sendAction` 会导致
    /// 「Window ordered front from a non-active application」警告且设置窗口可能不置前。
    /// 参照 `handleOpenMainWindow` 的模式，先将激活策略切换为 `.regular` 并激活应用，
    /// 再触发 Settings 场景。
    @MainActor @objc func handleOpenSettings()
    {
        if CommandLine.arguments.contains("--UITEST_SHOW_MAIN_WINDOW")
        {
            showSettingsInStandaloneWindow()
            return
        }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    /// 在独立 NSWindow 中显示设置视图（UI 测试模式专用）。
    /// 沿用 `MainWindow.showSettingsInStandaloneWindow` 的实现，确保窗口标题与标识符一致。
    @MainActor
    private func showSettingsInStandaloneWindow()
    {
        for window in NSApp.windows where window.title == "ClipMind Settings"
        {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 350),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "ClipMind Settings"
        window.contentViewController = NSHostingController(
            rootView: SettingsView(tagStore: tagStore)
        )
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
