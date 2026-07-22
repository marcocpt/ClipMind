import Foundation

/// F2.1 自动保存错误类型（D13 目录异常分级）。
public enum AutoSaveError: Error, LocalizedError
{
    case fileNameConflictExhausted
    case directoryCreationFailed(path: String)
    case fileWriteFailed(fileName: String)
    case permissionDenied(path: String)
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
        case .permissionDenied:
            return "权限不足"
        case .contentTooLarge:
            return "内容超过 100KB 上限"
        case .unsupportedContentType:
            return "不支持的剪贴板内容类型"
        }
    }
}
