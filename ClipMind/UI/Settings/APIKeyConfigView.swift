import SwiftUI

/// API Key 配置视图。
///
/// 支持选择 API 提供商、输入 API Key、验证 Key 有效性。
/// 验证成功显示绿色对勾，失败显示错误提示。
/// API Key 通过 `APIKeyManager` 安全存储到 Keychain。
///
/// 状态机对应设计规范 4.4 节：
/// 未配置 → 验证中 → 已配置_有效 / 已配置_无效 / 已配置_网络错误
struct APIKeyConfigView: View {
    @State private var keyManager = APIKeyManager()
    @State private var selectedProvider: APIProvider = .openai
    @State private var apiKeyInput: String = ""
    @State private var validationState: ValidationState = .idle
    @State private var errorMessage: String?

    /// API Key 验证状态。
    ///
    /// 对应设计规范 4.4 节状态机：
    /// - `idle`: 初始或已清除状态
    /// - `validating`: 验证请求进行中
    /// - `valid` / `invalid` / `networkError`: 验证结果
    enum ValidationState: Equatable {
        case idle
        case validating
        case valid
        case invalid
        case networkError
    }

    var body: some View {
        Form {
            providerSection
            apiKeySection
            statusSection
        }
        .onAppear {
            // UITEST_NO_API_KEY: 测试模式下确保 Keychain 干净，避免历史数据干扰
            if CommandLine.arguments.contains("--UITEST_NO_API_KEY") {
                keyManager.clearAll()
            }
            if let provider = keyManager.currentProvider {
                selectedProvider = provider
                loadSavedKey(for: provider)
            }
        }
    }

    // MARK: - 提供商选择

    private var providerSection: some View {
        Section("API 提供商") {
            Picker("提供商", selection: $selectedProvider) {
                ForEach(APIProvider.allCases, id: \.self) { provider in
                    Text(providerDisplayName(provider)).tag(provider)
                }
            }
            .onChange(of: selectedProvider) { newProvider in
                loadSavedKey(for: newProvider)
            }
            .accessibilityIdentifier("providerPicker")
        }
    }

    // MARK: - API Key 输入与验证

    private var apiKeySection: some View {
        Section("API Key") {
            SecureField("输入 API Key", text: $apiKeyInput)
                .accessibilityIdentifier("apiKeyInput")

            HStack {
                Button("验证") {
                    Task { await validateKey() }
                }
                .disabled(apiKeyInput.isEmpty || validationState == .validating)
                .accessibilityIdentifier("validateButton")

                validationIndicator
            }

            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .accessibilityIdentifier("validationErrorMessage")
            }
        }
    }

    /// 验证状态指示器：验证中显示进度，成功显示绿色对勾，失败显示红色叉号。
    @ViewBuilder
    private var validationIndicator: some View {
        if validationState == .validating {
            ProgressView().scaleEffect(0.7)
        }
        if validationState == .valid {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .accessibilityIdentifier("validationSuccess")
        }
        if validationState == .invalid || validationState == .networkError {
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.red)
                .accessibilityIdentifier("validationError")
        }
    }

    // MARK: - 当前配置状态

    @ViewBuilder
    private var statusSection: some View {
        Section("当前状态") {
            if keyManager.isConfigured {
                configuredStatusView
                Button("清除配置", role: .destructive) {
                    clearConfiguration()
                }
                .accessibilityIdentifier("clearConfigButton")
            } else {
                Label("未配置", systemImage: "exclamationmark.triangle")
                    .foregroundColor(.orange)
                    .accessibilityIdentifier("unconfiguredStatus")
            }
        }
    }

    private var configuredStatusView: some View {
        Label(
            "已配置（\(providerDisplayName(keyManager.currentProvider ?? .openai))）",
            systemImage: "checkmark.circle.fill"
        )
        .foregroundColor(.green)
        .accessibilityIdentifier("configuredStatus")
    }

    // MARK: - 业务逻辑

    /// 返回提供商的中文展示名。
    private func providerDisplayName(_ provider: APIProvider) -> String {
        switch provider {
        case .openai: return "OpenAI"
        case .zhipu: return "智谱"
        case .qianwen: return "通义"
        case .deepseek: return "DeepSeek"
        }
    }

    /// 切换提供商时加载已保存的 Key，并重置验证状态。
    private func loadSavedKey(for provider: APIProvider) {
        apiKeyInput = keyManager.loadKey(for: provider) ?? ""
        validationState = .idle
        errorMessage = nil
    }

    /// 验证当前输入的 API Key。
    ///
    /// 流程：保存 Key 到 Keychain → 调用 APIKeyManager 验证 → 更新 UI 状态。
    /// 对应 UI-AC-16 验证成功显示绿色对勾，失败显示错误。
    private func validateKey() async {
        validationState = .validating
        errorMessage = nil

        do {
            try keyManager.saveKey(apiKeyInput, for: selectedProvider)
            let result = await keyManager.validateKey(for: selectedProvider)
            applyValidationResult(result)
        } catch {
            validationState = .invalid
            errorMessage = error.localizedDescription
            LogCategory.llm.error("API Key 保存失败: \(error.localizedDescription)")
        }
    }

    /// 根据 ValidationResult 更新验证状态和错误信息。
    private func applyValidationResult(_ result: ValidationResult) {
        switch result {
        case .valid:
            validationState = .valid
            LogCategory.llm.info("API Key 验证成功 provider=\(selectedProvider.rawValue)")
        case .invalid:
            validationState = .invalid
            errorMessage = "API Key 无效，请检查后重试"
            LogCategory.llm.warning("API Key 验证失败 provider=\(selectedProvider.rawValue)")
        case .networkError:
            validationState = .networkError
            errorMessage = "网络错误，无法验证 API Key"
            LogCategory.llm.warning("API Key 验证网络错误 provider=\(selectedProvider.rawValue)")
        }
    }

    /// 清除所有 API Key 配置。
    private func clearConfiguration() {
        keyManager.clearAll()
        apiKeyInput = ""
        validationState = .idle
        errorMessage = nil
        LogCategory.llm.info("已清除 API Key 配置")
    }
}
