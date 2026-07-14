import ServiceManagement
import SwiftUI

/// 通用设置视图（T3.6 + F1.8 清除示例数据）。
///
/// 对应设计规范 3.8 节通用设置分区，包含：
/// - 开机启动开关（默认开）
/// - 快捷键配置（默认 cmd+shift+v）
/// - 清除示例数据按钮（F1.8 新增）
struct GeneralSettingsView: View {
    @AppStorage("launchAtLogin") private var launchAtLogin = true
    @AppStorage("hotkey") private var hotkey = "cmd+shift+v"
    @State private var showDeleteConfirmation = false

    var body: some View {
        Form {
            launchAtLoginSection
            hotkeySection
            sampleDataSection
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

    // MARK: - 清除示例数据（F1.8 新增）

    private var sampleDataSection: some View {
        Section("示例数据") {
            Button("清除示例数据") {
                showDeleteConfirmation = true
            }
            .accessibilityIdentifier("clearSampleDataButton")

            Text("清除首启注入的示例剪贴内容，真实复制内容不受影响。")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .confirmationDialog(
            "确定清除所有示例数据吗？",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("清除示例数据", role: .destructive) {
                clearSampleData()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("此操作将删除所有标记为示例的剪贴条目，不可撤销。真实复制的内容将保留。")
        }
    }

    /// 清除示例数据并通知 UI 刷新。
    ///
    /// 删除 is_sample=1 的行，发送 clipDidUpdateNotification 让 ClipStore 自动 loadClips。
    private func clearSampleData() {
        do {
            let store = try EncryptedStore()
            try store.deleteSamples()
            NotificationCenter.default.post(
                name: ClipCaptureService.clipDidUpdateNotification,
                object: nil
            )
            LogCategory.app.info("用户已清除示例数据")
        } catch {
            LogCategory.storage.error("清除示例数据失败: \(error.localizedDescription)")
        }
    }

    /// 更新开机启动注册状态。
    ///
    /// UI 测试只验证开关切换交互，不验证实际系统注册，
    /// 测试环境下跳过实际注册避免副作用。
    private func updateLaunchAtLogin(_ enabled: Bool) {
        guard !CommandLine.arguments.contains("--UITEST_SHOW_MAIN_WINDOW") else { return }

        if #available(macOS 13.0, *) {
            if enabled {
                try? SMAppService.mainApp.register()
                LogCategory.app.info("开机启动已开启")
            } else {
                try? SMAppService.mainApp.unregister()
                LogCategory.app.info("开机启动已关闭")
            }
        } else {
            // macOS 12 及以下：SMAppService 不可用，SMLoginItemSetEnabled 需要 helper bundle，
            // MVP 阶段暂不支持开机启动，仅记录日志。
            LogCategory.app.info("开机启动需 macOS 13+，当前系统版本不支持")
        }
    }
}
