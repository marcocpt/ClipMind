import SwiftUI
import UserNotifications

/// 权限请求页面视图
///
/// 引导用户授权辅助功能权限（必需）和通知权限（可选）。
struct PermissionRequestView: View {
    @State private var isAccessibilityGranted = false
    @State private var isNotificationGranted = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Text("权限设置")
                .font(.title2)
                .fontWeight(.bold)

            VStack(spacing: 20) {
                // 辅助功能权限
                PermissionRow(
                    icon: "hand.raised.fill",
                    title: "辅助功能",
                    description: "获取复制内容的来源应用，支持按来源筛选",
                    isGranted: isAccessibilityGranted,
                    action: openAccessibilitySettings,
                    buttonLabel: "打开系统设置"
                )
                .accessibilityIdentifier("accessibilityPermission")

                // 通知权限
                PermissionRow(
                    icon: "bell.fill",
                    title: "通知",
                    description: "复制敏感内容时弹出提醒",
                    isGranted: isNotificationGranted,
                    action: requestNotificationPermission,
                    buttonLabel: "授权通知"
                )
                .accessibilityIdentifier("notificationPermission")
            }
            .padding(.horizontal, 40)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("permissionRequestView")
        .onAppear { refreshPermissionStatus() }
    }

    /// 刷新权限状态
    private func refreshPermissionStatus() {
        isAccessibilityGranted = AXIsProcessTrusted()
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                isNotificationGranted = settings.authorizationStatus == .authorized
            }
        }
    }

    /// 打开系统设置辅助功能面板并触发 TCC 提示
    ///
    /// 委托给 `PermissionRequester.openAccessibilitySettingsAndPrompt()`，
    /// 调用顺序：先打开系统设置面板，再触发 TCC 提示对话框。
    /// 这样 TCC 提示对话框会显示在系统设置面板之上，用户能清晰看到并完成授权。
    private func openAccessibilitySettings() {
        PermissionRequester.openAccessibilitySettingsAndPrompt()
    }

    /// 请求通知权限
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, error in
            if let error = error {
                LogCategory.app.error("通知权限请求失败: \(error.localizedDescription)")
            }
            DispatchQueue.main.async { refreshPermissionStatus() }
        }
    }
}

/// 权限行组件
private struct PermissionRow: View {
    let icon: String
    let title: String
    let description: String
    let isGranted: Bool
    let action: () -> Void
    let buttonLabel: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.headline)
                    if isGranted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.callout)
                    }
                }
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !isGranted {
                Button(buttonLabel, action: action)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }
}
