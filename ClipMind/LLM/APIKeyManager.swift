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
        // 数据由本类的 saveKey 写入（Data(key.utf8)），UTF-8 编码可保证，使用非可选转换
        return String(decoding: data, as: UTF8.self)
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
    /// 当前实现为本地存在性检查：
    /// - Key 不存在 → `.invalid`
    /// - Key 已配置 → `.valid`
    ///
    /// 真实 API 请求验证（如调用 `/v1/models`）将在 T2.6 UI 集成时实现，
    /// 届时网络异常会返回 `.networkError`。
    /// - Parameter provider: API 提供商
    /// - Returns: 验证结果（valid / invalid / networkError），不抛错
    func validateKey(for provider: APIProvider) async -> ValidationResult {
        guard loadKey(for: provider) != nil else {
            LogCategory.llm.info("validateKey: provider=\(provider.rawValue) 未配置 key，返回 invalid")
            return .invalid
        }
        LogCategory.llm.info("validateKey: provider=\(provider.rawValue) key 已配置，返回 valid（暂未发起 API 请求）")
        return .valid
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
