import Foundation

/// 标签名称规范化边界。
///
/// 创建、重命名和 UI preflight 共同使用的纯领域规则：trim、全局唯一（大小写不敏感）和重命名排除自身。
enum TagNameValidator
{
    /// 校验候选名称，返回 trim 后的合法名称。
    ///
    /// - Parameters:
    ///   - candidate: 候选名称
    ///   - existingTags: 现有标签集合（系统 + 用户）
    ///   - excludedID: 重命名时排除自身的 ID
    /// - Returns: trim 后的合法名称
    /// - Throws: `TagError.emptyName` 或 `TagError.duplicateName`
    static func validate(
        candidate: String,
        existingTags: [ClipTag],
        excluding excludedID: ClipTagID? = nil
    ) throws -> String
    {
        let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw TagError.emptyName }

        let key = trimmed.folding(
            options: [.caseInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        )
        let hasDuplicate = existingTags.contains
        {
            $0.id != excludedID
                && $0.name.folding(
                    options: [.caseInsensitive],
                    locale: Locale(identifier: "en_US_POSIX")
                ) == key
        }
        guard !hasDuplicate else { throw TagError.duplicateName }
        return trimmed
    }
}
