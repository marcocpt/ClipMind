import ServiceManagement
import SwiftUI

/// 通用设置视图（T3.6）
///
/// 对应设计规范 3.8 节通用设置分区，包含：
/// - 开机启动开关（默认开）
/// - 快捷键配置（默认 cmd+shift+v）
struct GeneralSettingsView: View {
    @AppStorage("launchAtLogin") private var launchAtLogin = true
    @AppStorage("hotkey") private var hotkey = "cmd+shift+v"

    var body: some View {
        Form {
            launchAtLoginSection
            hotkeySection
        }
        .padding()
    }

    // MARK: - 开机启动

    private var launchAtLoginSection: some View {
        Section("开机启动") {
            Toggle("开机时自动启动 ClipMind", isOn: $launchAtLogin)
                .accessibilityIdentifier("launchAtLoginToggle")
                .onChange(of: launchAtLogin) { newValue in
                    updateLaunchAtLogin(newValue)
                }

            Text("开启后，系统登录时自动启动 ClipMind。")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - 快捷键配置

    private var hotkeySection: some View {
        Section("快捷键") {
            HotkeyRecorder(hotkey: $hotkey)

            Text("用于唤起 ClipMind 剪贴板历史窗口。")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    /// 更新开机启动注册状态。
    ///
    /// UI 测试只验证开关切换交互，不验证实际系统注册，
    /// 测试环境下跳过实际注册避免副作用。
    private func updateLaunchAtLogin(_ enabled: Bool) {
        guard !CommandLine.arguments.contains("--UITEST_SHOW_MAIN_WINDOW") else { return }

        if enabled {
            try? SMAppService.mainApp.register()
            LogCategory.app.info("开机启动已开启")
        } else {
            try? SMAppService.mainApp.unregister()
            LogCategory.app.info("开机启动已关闭")
        }
    }
}
