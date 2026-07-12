import Foundation
import Security

/// API Key 验证结果。
///
/// 用于 `APIKeyManager.validateKey` 的返回值，UI 层据此显示配置状态：
/// - `valid`: API Key 已配置且通过校验，可启用一键处理
/// - `invalid`: API Key 不存在或被服务端拒绝
/// - `networkError`: 网络异常，无法判断有效性
enum ValidationResult: Equatable {
    case valid
    case invalid
    case networkError
}

/// API Key 操作错误类型。
///
/// 封装 Keychain 操作失败的具体场景，便于 UI 层精确提示。
enum APIKeyError: LocalizedError {
    /// Keychain 写入失败（携带 OSStatus）
    case keychainSaveFailed(OSStatus)
    /// Keychain 读取失败（携带 OSStatus）
    case keychainLoadFailed(OSStatus)
    /// Keychain 删除失败（携带 OSStatus）
    case keychainDeleteFailed(OSStatus)
    /// Keychain 已存在同 service+account 的条目（理论上 saveKey 已先 delete，不应出现）
    case keychainDuplicateItem
    /// 待保存的 API Key 为空字符串
    case emptyKey

    var errorDescription: String? {
        switch self {
        case let .keychainSaveFailed(status):
            return "API Key 保存失败（Keychain 错误码：\(status)）"
        case let .keychainLoadFailed(status):
            return "API Key 读取失败（Keychain 错误码：\(status)）"
        case let .keychainDeleteFailed(status):
            return "API Key 删除失败（Keychain 错误码：\(status)）"
        case .keychainDuplicateItem:
            return "API Key 已存在，请勿重复保存"
        case .emptyKey:
            return "API Key 不能为空"
        }
    }
}

/// API Key 管理器。
///
/// 负责 API Key 的安全存储（Keychain）和验证状态管理。
/// API Key 存储在 macOS Keychain 中，API Provider 存储在 UserDefaults（非敏感信息）。
/// Key 按 provider 区分存储，service = "com.clipmind.app.apikey.<provider>"。
final class APIKeyManager {
    /// Keychain service 前缀，实际 service 拼接 provider.rawValue
    private static let keychainService = "com.clipmind.app.apikey"
    /// Keychain account（固定值，与 service 共同定位条目）
    private static let keychainAccount = "llm_api_key"
    /// UserDefaults 中 apiProvider 的 key
    private static let providerKey = "apiProvider"

    /// 用于发起验证请求的 URLSession（测试可注入 InterceptingURLProtocol）
    private let urlSession: URLSession

    /// 初始化。
    /// - Parameter urlSession: 用于发起 API 验证请求的 URLSession（默认 .shared，测试可注入）
    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    /// 当前配置的 API Provider（从 UserDefaults 读取，每次调用实时获取）
    var currentProvider: APIProvider? {
        guard let raw = UserDefaults.standard.string(forKey: Self.providerKey) else {
            return nil
        }
        return APIProvider(rawValue: raw)
    }

    /// 当前是否已配置 API Key。
    ///
    /// 仅当 `currentProvider` 非空且该 provider 在 Keychain 中存在 key 时返回 true。
    /// 不返回 key 本身，避免敏感信息泄漏到 UI 层。
    var isConfigured: Bool {
        guard let provider = currentProvider else { return false }
        return loadKey(for: provider) != nil
    }

    /// 保存 API Key 到 Keychain。
    ///
    /// - Parameters:
    ///   - key: API Key 字符串（不能为空）
    ///   - provider: API 提供商
    /// - Throws: `APIKeyError.emptyKey` 当 key 为空；`APIKeyError.keychainSaveFailed` 当 Keychain 写入失败
    func saveKey(_ key: String, for provider: APIProvider) throws {
        guard !key.isEmpty else {
            LogCategory.llm.warning("尝试保存空 API Key，已拒绝")
            throw APIKeyError.emptyKey
        }

        // 先删除已有 key，确保 update 语义（避免 errSecDuplicateItem）
        deleteKey(for: provider)

        let data = Data(key.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service(for: provider),
            kSecAttrAccount as String: Self.keychainAccount,
            kSecValueData as String: data
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            LogCategory.llm.error("Keychain 保存失败 provider=\(provider.rawValue) status=\(status)")
            throw APIKeyError.keychainSaveFailed(status)
        }

        // 同步更新 currentProvider 到 UserDefaults
        UserDefaults.standard.set(provider.rawValue, forKey: Self.providerKey)
        LogCategory.llm.info("API Key 已保存 provider=\(provider.rawValue)")
    }

    /// 读取 API Key。
    ///
    /// - Parameter provider: API 提供商
    /// - Returns: API Key 字符串；未配置或读取失败时返回 nil（不抛错，UI 层只关心存在性）
    func loadKey(for provider: APIProvider) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service(for: provider),
            kSecAttrAccount as String: Self.keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            LogCategory.llm.error("Keychain 读取失败 provider=\(provider.rawValue) status=\(status)")
            return nil
        }
        guard let data = result as? Data else {
            LogCategory.llm.warning("Keychain 数据格式异常 provider=\(provider.rawValue)")
            return nil
        }
        // 数据由本类的 saveKey 写入（Data(key.utf8)），UTF-8 编码可保证；
        // 使用可失败初始化器以满足 SwiftLint optional_data_string_conversion 规则
        return String(data: data, encoding: .utf8)
    }

    /// 删除 API Key（从 Keychain）。
    ///
    /// 幂等操作：删除不存在的 key 视为成功，不抛错。
    /// - Parameter provider: API 提供商
    func deleteKey(for provider: APIProvider) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service(for: provider),
            kSecAttrAccount as String: Self.keychainAccount
        ]

        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            LogCategory.llm.error("Keychain 删除失败 provider=\(provider.rawValue) status=\(status)")
        }
    }

    /// 验证 API Key 是否有效。
    ///
    /// 实现真实 API 验证：调用各提供商的 `/v1/models`（或等价）端点。
    /// - Key 不存在（Keychain 中无 key）→ 直接返回 `.invalid`（快速失败，不发起网络请求）
    /// - 200 → `.valid`
    /// - 401/403 → `.invalid`（API Key 被服务端拒绝）
    /// - 其他状态码或网络错误 → `.networkError`（无法判断有效性）
    ///
    /// 各 provider 的验证端点：
    /// - OpenAI: `https://api.openai.com/v1/models`（GET，Authorization: Bearer <key>）
    /// - 智谱 GLM: `https://open.bigmodel.cn/api/paas/v4/models`（GET，Authorization: Bearer <key>）
    /// - 通义千问: `https://dashscope.aliyuncs.com/api/v1/models`（GET，Authorization: Bearer <key>）
    /// - DeepSeek: `https://api.deepseek.com/v1/models`（GET，Authorization: Bearer <key>）
    /// - Parameter provider: API 提供商
    /// - Returns: 验证结果（valid / invalid / networkError），不抛错
    func validateKey(for provider: APIProvider) async -> ValidationResult {
        // 快速失败：Keychain 中无 key 时直接返回 invalid（不发起网络请求）
        guard let key = loadKey(for: provider) else {
            LogCategory.llm.info("validateKey: provider=\(provider.rawValue) 未配置 key，返回 invalid")
            return .invalid
        }

        let url = validationURL(for: provider)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")

        do {
            let (_, response) = try await urlSession.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                LogCategory.llm.warning("validateKey: 非 HTTP 响应 provider=\(provider.rawValue)")
                return .networkError
            }
            switch http.statusCode {
            case 200...299:
                LogCategory.llm.info("validateKey: provider=\(provider.rawValue) 验证成功 (\(http.statusCode))")
                return .valid
            case 401, 403:
                LogCategory.llm.warning("validateKey: provider=\(provider.rawValue) 被拒绝 (\(http.statusCode))")
                return .invalid
            default:
                LogCategory.llm.warning("validateKey: provider=\(provider.rawValue) 异常状态码 \(http.statusCode)")
                return .networkError
            }
        } catch {
            LogCategory.llm.warning("validateKey: provider=\(provider.rawValue) 网络错误: \(error.localizedDescription)")
            return .networkError
        }
    }

    /// 根据 provider 返回验证 API 的 URL（`/v1/models` 或等价端点）。
    /// - Parameter provider: API 提供商
    /// - Returns: 验证端点 URL
    private func validationURL(for provider: APIProvider) -> URL {
        switch provider {
        case .openai:
            return URL(string: "https://api.openai.com/v1/models")!
        case .zhipu:
            return URL(string: "https://open.bigmodel.cn/api/paas/v4/models")!
        case .qianwen:
            return URL(string: "https://dashscope.aliyuncs.com/api/v1/models")!
        case .deepseek:
            return URL(string: "https://api.deepseek.com/v1/models")!
        }
    }

    /// 清除所有配置（所有 provider 的 Keychain 条目 + UserDefaults 中的 provider）。
    func clearAll() {
        for provider in APIProvider.allCases {
            deleteKey(for: provider)
        }
        UserDefaults.standard.removeObject(forKey: Self.providerKey)
        LogCategory.llm.info("已清除所有 API Key 配置")
    }

    /// 构造 per-provider 的 Keychain service 标识。
    /// - Parameter provider: API 提供商
    /// - Returns: 形如 "com.clipmind.app.apikey.openai" 的字符串
    private func service(for provider: APIProvider) -> String {
        "\(Self.keychainService).\(provider.rawValue)"
    }
}
