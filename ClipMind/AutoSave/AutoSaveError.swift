import Foundation

/// F2.1 自动保存错误类型（D13 目录异常分级）。
///
/// NFR-007/D15：错误不携带 fileName/path 等可派生自剪贴板原文的敏感字段；
/// 路径相关日志通过 `pathHash` 输出 SHA-256 前 8 位，避免泄露用户名/内容前缀。
public enum AutoSaveError: Error, LocalizedError
{
    case fileNameConflictExhausted
    case directoryCreationFailed
    case fileWriteFailed
    case fileAlreadyExists
    case permissionDenied
    case diskFull
    case contentTooLarge
    case unsupportedContentType

    public var errorDescription: String?
    {
        switch self
        {
        case .fileNameConflictExhausted:
            return "文件名冲突重试次数已耗尽"
        case .directoryCreationFailed:
            return "保存目录创建失败"
        case .fileWriteFailed:
            return "文件写入失败"
        case .fileAlreadyExists:
            return "文件已存在"
        case .permissionDenied:
            return "权限不足"
        case .diskFull:
            return "磁盘空间不足"
        case .contentTooLarge:
            return "内容超过 100KB 上限"
        case .unsupportedContentType:
            return "不支持的剪贴板内容类型"
        }
    }
}
