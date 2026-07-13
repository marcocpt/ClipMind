import SwiftUI

/// 一键处理按钮组（T2.5）。
///
/// 显示 4 种 AI 处理按钮，根据 API Key 配置状态启用/置灰。
/// 点击按钮触发对应处理，处理中显示加载动画。
struct ProcessingButtons: View {
    /// API Key 是否已配置
    let isConfigured: Bool
    /// 是否正在处理
    let isProcessing: Bool
    /// 点击智能总结
    let onSummarize: () -> Void
    /// 点击即时翻译
    let onTranslate: () -> Void
    /// 点击智能改写
    let onRewrite: () -> Void
    /// 点击提取待办
    let onExtractTodo: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                button(
                    title: "智能总结",
                    icon: "text.badge.checkmark",
                    identifier: "summarizeButton",
                    action: onSummarize
                )
                button(
                    title: "即时翻译",
                    icon: "globe",
                    identifier: "translateButton",
                    action: onTranslate
                )
            }
            HStack(spacing: 8) {
                button(
                    title: "智能改写",
                    icon: "pencil",
                    identifier: "rewriteButton",
                    action: onRewrite
                )
                button(
                    title: "提取待办",
                    icon: "checklist",
                    identifier: "extractTodoButton",
                    action: onExtractTodo
                )
            }
            if isProcessing {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityIdentifier("processingIndicator")
            }
        }
    }

    /// 构造单个处理按钮
    private func button(
        title: String,
        icon: String,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .accessibilityIdentifier(identifier)
        .disabled(!isConfigured || isProcessing)
    }
}
