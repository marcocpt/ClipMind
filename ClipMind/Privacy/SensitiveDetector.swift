import Foundation

/// 敏感内容类型
enum SensitiveType: String, CaseIterable {
    case password
    case token
    case verificationCode
    case bankCard
    case idCard
    case sensitiveKeyword
}

/// 敏感内容识别器（T3.1）
///
/// 检测剪贴板文本是否包含敏感信息，支持 6 种敏感模式：
/// - 密码模式（password=xxx）
/// - Token 格式（sk-/ghp_/gho_/Bearer 前缀 + 32 位）
/// - 验证码（4-8 位纯数字）
/// - 银行卡号（16-19 位 + Luhn 校验）
/// - 身份证号（18 位 + 校验码验证）
/// - 敏感关键词（password/secret/api_key/access_token/private_key）
struct SensitiveDetector {
    /// UserDefaults 键名（与 @AppStorage 共用）
    static let storageKey = "sensitiveDetectionEnabled"

    /// UserDefaults 实例（支持注入用于测试）
    private let defaults: UserDefaults

    /// 初始化
    /// - Parameter defaults: UserDefaults 实例，默认为 .standard
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// 敏感识别开关（默认 true）
    var sensitiveDetectionEnabled: Bool {
        // 未设置时返回默认值 true
        if defaults.object(forKey: Self.storageKey) == nil {
            return true
        }
        return defaults.bool(forKey: Self.storageKey)
    }

    /// 检测文本是否包含敏感内容
    /// - Parameter text: 待检测文本
    /// - Returns: true 表示包含敏感内容
    func detect(_ text: String) -> Bool {
        guard sensitiveDetectionEnabled else { return false }
        return performDetection(text) != nil
    }

    /// 返回具体敏感类型
    /// - Parameter text: 待检测文本
    /// - Returns: 敏感类型，非敏感时返回 nil
    func detect(_ text: String) -> SensitiveType? {
        guard sensitiveDetectionEnabled else { return nil }
        return performDetection(text)
    }
}

// MARK: - 检测调度

private extension SensitiveDetector {
    /// 执行敏感内容检测（按优先级依次检查）
    func performDetection(_ text: String) -> SensitiveType? {
        if let type = detectPassword(text) { return type }
        if let type = detectToken(text) { return type }
        if let type = detectIDCard(text) { return type }
        if let type = detectBankCard(text) { return type }
        if let type = detectVerificationCode(text) { return type }
        if let type = detectKeyword(text) { return type }
        return nil
    }

    // MARK: 密码模式

    /// 密码模式：password\s*[=:]\s*\S+
    func detectPassword(_ text: String) -> SensitiveType? {
        let pattern = #"password\s*[=:]\s*\S+"#
        return match(pattern: pattern, in: text) ? .password : nil
    }

    // MARK: Token 格式

    /// Token 格式：sk-/ghp_/gho_/Bearer 前缀 + 32 位非空白字符
    func detectToken(_ text: String) -> SensitiveType? {
        let pattern = #"^(?:sk-|ghp_|gho_|Bearer\s)\S{32,}"#
        return match(pattern: pattern, in: text) ? .token : nil
    }

    // MARK: 验证码

    /// 验证码：4-8 位纯数字
    func detectVerificationCode(_ text: String) -> SensitiveType? {
        let pattern = #"^\d{4,8}$"#
        return fullMatch(pattern: pattern, in: text) ? .verificationCode : nil
    }

    // MARK: 银行卡号

    /// 银行卡号：16-19 位纯数字 + Luhn 校验
    func detectBankCard(_ text: String) -> SensitiveType? {
        let pattern = #"^\d{16,19}$"#
        guard fullMatch(pattern: pattern, in: text) else { return nil }
        return luhnCheck(text) ? .bankCard : nil
    }

    // MARK: 身份证号

    /// 身份证号：18 位（前 17 位数字 + 末位数字/X）+ 校验码验证
    func detectIDCard(_ text: String) -> SensitiveType? {
        let pattern = #"^\d{17}[\dXx]$"#
        guard fullMatch(pattern: pattern, in: text) else { return nil }
        return idCardCheck(text) ? .idCard : nil
    }

    // MARK: 敏感关键词

    /// 敏感关键词：password/secret/api_key/access_token/private_key（不区分大小写）
    func detectKeyword(_ text: String) -> SensitiveType? {
        let pattern = "password|secret|api_key|access_token|private_key"
        return match(pattern: pattern, in: text, options: .caseInsensitive) ? .sensitiveKeyword : nil
    }
}

// MARK: - 正则辅助

private extension SensitiveDetector {
    /// 正则搜索（firstMatch，可匹配子串）
    func match(
        pattern: String,
        in text: String,
        options: NSRegularExpression.Options = []
    ) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return false
        }
        let range = NSRange(text.startIndex..., in: text)
        return regex.firstMatch(in: text, range: range) != nil
    }

    /// 正则全匹配（整个字符串需匹配模式）
    func fullMatch(pattern: String, in text: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return false
        }
        let range = NSRange(text.startIndex..., in: text)
        guard let result = regex.firstMatch(in: text, range: range) else {
            return false
        }
        return result.range.length == range.length
    }
}

// MARK: - Luhn 校验

private extension SensitiveDetector {
    /// Luhn 校验算法（银行卡号）
    /// - Parameter number: 纯数字字符串
    /// - Returns: true 表示通过 Luhn 校验
    func luhnCheck(_ number: String) -> Bool {
        var sum = 0
        var doubleNext = false
        for char in number.reversed() {
            guard let digit = char.wholeNumberValue else { return false }
            if doubleNext {
                let doubled = digit * 2
                sum += doubled > 9 ? doubled - 9 : doubled
            } else {
                sum += digit
            }
            doubleNext.toggle()
        }
        return sum % 10 == 0
    }
}

// MARK: - 身份证校验

private extension SensitiveDetector {
    /// 身份证号校验码验证
    /// - Parameter idNumber: 18 位身份证号
    /// - Returns: true 表示校验码正确
    func idCardCheck(_ idNumber: String) -> Bool {
        // 加权因子
        let weights = [7, 9, 10, 5, 8, 4, 2, 1, 6, 3, 7, 9, 10, 5, 8, 4, 2]
        // 校验码映射（取模 11 后对应：0→1, 1→0, 2→X, 3→9, ...）
        let checkCodes: [Character] = ["1", "0", "X", "9", "8", "7", "6", "5", "4", "3", "2"]

        let digits = Array(idNumber)
        guard digits.count == 18 else { return false }

        var sum = 0
        for index in 0..<17 {
            guard let digit = digits[index].wholeNumberValue else { return false }
            sum += digit * weights[index]
        }

        let remainder = sum % 11
        let expected = checkCodes[remainder]
        // 不区分大小写比较（X 或 x 均接受）
        return digits[17].uppercased() == String(expected).uppercased()
    }
}
