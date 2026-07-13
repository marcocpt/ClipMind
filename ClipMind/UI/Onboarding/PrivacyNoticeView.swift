import SwiftUI

/// 隐私默认值提示页面视图
///
/// 展示隐私保护的3个默认设置项，强调数据仅存储在本机。
struct PrivacyNoticeView: View {
    /// 完成回调
    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Text("隐私保护已默认开启")
                .font(.title2)
                .fontWeight(.bold)

            VStack(spacing: 16) {
                PrivacyRow(
                    icon: "eye.slash.fill",
                    title: "敏感内容识别",
                    detail: "自动识别并忽略密码、Token等敏感信息",
                    status: "已开启"
                )

                PrivacyRow(
                    icon: "app.badge.fill",
                    title: "应用黑名单",
                    detail: "1Password/钥匙串/银行App的复制内容自动忽略",
                    status: "已开启"
                )

                PrivacyRow(
                    icon: "clock.badge.checkmark.fill",
                    title: "自动清理",
                    detail: "30天前的内容自动清理",
                    status: "30天"
                )
            }
            .padding(.horizontal, 40)

            Text("所有数据仅存储在本机，不会上传到云端")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            Button("开始使用 ClipMind") {
                onFinish()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityIdentifier("finishButton")

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("privacyNoticeView")
    }
}

/// 隐私设置行组件
private struct PrivacyRow: View {
    let icon: String
    let title: String
    let detail: String
    let status: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(status)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.green)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }
}
