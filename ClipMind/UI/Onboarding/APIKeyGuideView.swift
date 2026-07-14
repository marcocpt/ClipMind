import SwiftUI

/// API Key 配置引导页面视图
///
/// 简化版 API Key 配置界面，可跳过。
/// 跳过后提示分类和搜索本地可用，AI 处理需配置 API Key。
struct APIKeyGuideView: View {
    @State private var keyManager = APIKeyManager()
    @State private var selectedProvider: APIProvider = .openai
    @State private var apiKey = ""
    @State private var validationResult: ValidationResult?
    @State private var isValidating = false

    /// 跳过提示框显示状态（由 OnboardingView 直接绑定）
    @Binding var showSkipAlert: Bool

    /// 跳过确认后的回调
    var onSkipConfirmed: (() -> Void)?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("API Key 配置")
                .font(.title2)
                .fontWeight(.bold)

            Text("配置 AI 提供商的 API Key，启用智能总结、翻译、改写和待办提取功能")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            VStack(spacing: 16) {
                // 提供商选择
                HStack {
                    Text("AI 提供商")
                        .frame(width: 80, alignment: .trailing)
                    Picker("AI 提供商", selection: $selectedProvider) {
                        ForEach(APIProvider.allCases, id: \.self) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }
                    .labelsHidden()
                    Spacer()
                }

                // API Key 输入
                HStack {
                    Text("API Key")
                        .frame(width: 80, alignment: .trailing)
                    SecureField("输入 API Key", text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("apiKeyInput")
                    Button("验证") {
                        Task { await validateKey() }
                    }
                    .disabled(apiKey.isEmpty || isValidating)
                }

                // 验证结果
                if let result = validationResult {
                    validationResultRow(result)
                }
            }
            .padding(.horizontal, 40)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("apiKeyGuideView")
        .alert("提示", isPresented: $showSkipAlert) {
            Button("确定") {
                onSkipConfirmed?()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("分类和搜索本地可用，AI 处理需配置 API Key")
        }
    }

    @ViewBuilder
    private func validationResultRow(_ result: ValidationResult) -> some View {
        HStack {
            Spacer()
            switch result {
            case .valid:
                Label("验证通过", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .invalid:
                Label("API Key 无效", systemImage: "xmark.circle.fill")
                    .foregroundStyle(.red)
            case .networkError:
                Label("网络错误，请稍后重试", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
            Spacer()
        }
        .padding(.horizontal, 40)
    }

    /// 验证 API Key
    private func validateKey() async {
        isValidating = true
        validationResult = nil

        do {
            try keyManager.saveKey(apiKey, for: selectedProvider)
        } catch {
            validationResult = .invalid
            isValidating = false
            return
        }

        let result = await keyManager.validateKey(for: selectedProvider)
        validationResult = result
        isValidating = false

        if case .invalid = result {
            keyManager.deleteKey(for: selectedProvider)
        }
    }
}

// MARK: - APIProvider 扩展

extension APIProvider {
    /// 中文显示名称
    var displayName: String {
        switch self {
        case .openai: return "OpenAI"
        case .zhipu: return "智谱 GLM"
        case .qianwen: return "通义千问"
        case .deepseek: return "DeepSeek"
        }
    }
}
