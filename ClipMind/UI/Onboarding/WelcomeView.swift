import SwiftUI

/// 欢迎页面视图
///
/// 展示 ClipMind 的核心价值主张：智能分类、即时搜索、一键处理。
struct WelcomeView: View {
    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // 标题区域
            VStack(spacing: 8) {
                Image(systemName: "doc.on.clipboard.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.tint)
                Text("欢迎使用 ClipMind")
                    .font(.title)
                    .fontWeight(.bold)
                Text("你的 AI 智能剪贴板")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            // 核心功能描述
            VStack(spacing: 16) {
                FeatureRow(
                    icon: "brain",
                    title: "智能分类",
                    description: "自动识别11种内容类型"
                )
                FeatureRow(
                    icon: "magnifyingglass",
                    title: "即时搜索",
                    description: "语义搜索，秒级找到"
                )
                FeatureRow(
                    icon: "bolt.fill",
                    title: "一键处理",
                    description: "总结、翻译、改写、提取待办"
                )
            }
            .padding(.horizontal, 48)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("welcomeView")
    }
}

/// 功能描述行组件
private struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}
