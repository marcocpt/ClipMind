import Foundation

/// LLM 服务错误类型（T2.1）。
///
/// 封装所有 LLM API 调用可能出现的错误场景，
/// UI 层据此决定：是否置灰按钮、是否重试、是否弹出提示。
enum LLMError: LocalizedError, Equatable {
    /// 未配置 API Key（按钮应置灰并提示用户去设置）
    case notConfigured
    /// API Key 无效（被服务端拒绝，401）
    case invalidAPIKey
    /// 网络错误（连接失败、DNS 解析失败等）
    case networkError(Error)
    /// 限流（429，应提示用户稍后重试）
    case rateLimited
    /// 响应解析失败（JSON 格式错误、字段缺失等）
    case parseError(String)
    /// 请求超时（30s 内未收到响应）
    case timeout
    /// 服务器错误（5xx，附状态码）
    case serverError(Int)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "未配置 API Key，请先在设置中配置"
        case .invalidAPIKey:
            return "API Key 无效，请检查配置"
        case .networkError:
            return "网络连接失败，请检查网络后重试"
        case .rateLimited:
            return "请求过于频繁，请稍后重试"
        case .parseError(let message):
            return "响应解析失败：\(message)"
        case .timeout:
            return "请求超时，请稍后重试"
        case .serverError(let code):
            return "服务器错误（状态码：\(code)）"
        }
    }

    static func == (lhs: LLMError, rhs: LLMError) -> Bool {
        switch (lhs, rhs) {
        case (.notConfigured, .notConfigured):
            return true
        case (.invalidAPIKey, .invalidAPIKey):
            return true
        case (.networkError, .networkError):
            return true
        case (.rateLimited, .rateLimited):
            return true
        case let (.parseError(lhsMsg), .parseError(rhsMsg)):
            return lhsMsg == rhsMsg
        case (.timeout, .timeout):
            return true
        case let (.serverError(lhsCode), .serverError(rhsCode)):
            return lhsCode == rhsCode
        default:
            return false
        }
    }
}
