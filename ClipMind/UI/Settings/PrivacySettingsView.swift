import SwiftUI

/// 隐私设置视图（T3.5）
///
/// 对应设计规范 3.8 节隐私设置分区，包含：
/// - 敏感识别开关（默认开）
/// - 自动清理开关 + 清理周期选择（7/14/30/90 天）
/// - 应用黑名单管理（嵌入 BlacklistManagementView）
///
/// AC 映射：AC-22（敏感识别开关 UI 切换）、AC-21（清理周期配置 UI）
struct PrivacySettingsView: View {
    @AppStorage("sensitiveDetectionEnabled") private var sensitiveDetectionEnabled = true
    @AppStorage("autoCleanupEnabled") private var autoCleanupEnabled = true
    @AppStorage("cleanupDays") private var cleanupDays = 30

    var body: some View {
        Form {
            sensitiveSection
            cleanupSection
            BlacklistManagementView()
        }
        .padding()
    }

    // MARK: - 敏感识别

    private var sensitiveSection: some View {
        Section("敏感识别") {
            Toggle("启用敏感内容识别", isOn: $sensitiveDetectionEnabled)
                .accessibilityIdentifier("sensitiveDetectionToggle")

            Text("开启后，复制密码、Token、银行卡号等敏感内容时自动忽略，不入库。")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - 自动清理

    private var cleanupSection: some View {
        Section("自动清理") {
            Toggle("启用自动清理", isOn: $autoCleanupEnabled)
                .accessibilityIdentifier("autoCleanupToggle")

            if autoCleanupEnabled {
                Picker("清理周期", selection: $cleanupDays) {
                    Text("7 天").tag(7)
                    Text("14 天").tag(14)
                    Text("30 天（默认）").tag(30)
                    Text("90 天").tag(90)
                }
                .accessibilityIdentifier("cleanupDaysPicker")

                Text("超过清理周期的历史条目将自动删除。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
