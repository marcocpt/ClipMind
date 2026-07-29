import Foundation

/// 标签操作类型（闭集）。
enum TagOperation: String, Equatable, Sendable
{
    case create
    case attach
    case detach
    case rename
    case delete
    case migrate
}

/// 标签操作结果（闭集）。
enum TagOperationResult: String, Equatable, Sendable
{
    case success
    case failure
}

/// 标签操作日志端口。
///
/// 只接收枚举和计数，没有可传入任意 String 的参数，确保标签名和剪贴板内容不进入日志。
protocol TagOperationLogging
{
    func record(
        operation: TagOperation,
        result: TagOperationResult,
        error: TagError?,
        count: Int
    )
}

/// 生产标签操作日志。
///
/// 格式只包含闭集 `operation`、`result`、`error?.rawValue` 和 `count`。
final class DefaultTagOperationLogger: TagOperationLogging
{
    func record(
        operation: TagOperation,
        result: TagOperationResult,
        error: TagError?,
        count: Int
    )
    {
        let errorText = error?.rawValue ?? "none"
        LogCategory.storage.info(
            "tag operation=\(operation.rawValue) result=\(result.rawValue) error=\(errorText) count=\(count)"
        )
    }
}
