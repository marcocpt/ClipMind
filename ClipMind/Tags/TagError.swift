import Foundation

/// 标签业务错误。
///
/// 固定错误码和不含标签名或剪贴板内容的安全文案。
enum TagError: String, Error, LocalizedError, Equatable, Sendable
{
    case emptyName
    case duplicateName
    case tagLimitReached
    case systemTagNotEligible
    case systemTagReadOnly
    case tagNotFound
    case clipNotFound
    case persistenceFailed

    var errorDescription: String?
    {
        switch self
        {
        case .emptyName:
            return "标签名称不能为空"
        case .duplicateName:
            return "已存在同名标签"
        case .tagLimitReached:
            return "每条条目最多 5 个标签"
        case .systemTagNotEligible:
            return "该自动分类标签不适用于当前条目"
        case .systemTagReadOnly:
            return "自动分类标签不可全局修改"
        case .tagNotFound, .clipNotFound, .persistenceFailed:
            return "未能保存标签操作，已恢复之前的状态"
        }
    }

    /// 是否为业务校验错误（已在方法内记录日志，不需要在 catch 中重复记录）。
    var isBusinessValidation: Bool
    {
        switch self
        {
        case .emptyName, .duplicateName, .tagLimitReached,
             .systemTagNotEligible, .systemTagReadOnly,
             .tagNotFound, .clipNotFound:
            return true
        case .persistenceFailed:
            return false
        }
    }
}
