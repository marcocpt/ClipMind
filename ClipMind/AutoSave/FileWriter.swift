import Darwin
import Foundation

/// 文件写入器（D10 O_EXCL 原子创建 + D14 0600 权限 + D13 异常分级）。
public struct FileWriter
{
    private static let filePermissions: mode_t = 0o600

    private let logger = LogCategory.storage.logger

    public init() {}

    public func write(content: String, to url: URL) throws
    {
        let directory = url.deletingLastPathComponent()
        let fileManager = FileManager.default

        // D13：目录不存在时创建
        if !fileManager.fileExists(atPath: directory.path)
        {
            do {
                try fileManager.createDirectory(
                    at: directory,
                    withIntermediateDirectories: true,
                    attributes: [.posixPermissions: 0o755]
                )
            } catch {
                logger.error("Directory creation failed: errorCode=\(error._code, privacy: .public)")
                throw AutoSaveError.directoryCreationFailed(path: directory.path)
            }
        }

        // D10：O_EXCL 原子创建 + D14：0600 权限（POSIX open 一步到位）
        let data = Data(content.utf8)
        let fileDescriptor = url.path.withCString { pathCString in
            open(pathCString, O_CREAT | O_EXCL | O_WRONLY, Self.filePermissions)
        }

        if fileDescriptor == -1
        {
            let errnoValue = errno
            switch errnoValue
            {
            case EEXIST:
                logger.error("File exists: fileName=\(url.lastPathComponent, privacy: .public)")
                throw AutoSaveError.fileWriteFailed(fileName: url.lastPathComponent)
            case EACCES, EPERM:
                logger.error("Permission denied: errno=\(errnoValue, privacy: .public)")
                throw AutoSaveError.permissionDenied(path: url.path)
            default:
                logger.error("Open failed: errno=\(errnoValue, privacy: .public)")
                throw AutoSaveError.fileWriteFailed(fileName: url.lastPathComponent)
            }
        }

        defer {
            close(fileDescriptor)
        }

        // 写入数据；失败时清理半成品文件（D10）
        do {
            try Self.writeAll(fileDescriptor: fileDescriptor, data: data)
        } catch {
            try? fileManager.removeItem(at: url)
            logger.error("Write failed, cleaned up: fileName=\(url.lastPathComponent, privacy: .public)")
            throw AutoSaveError.fileWriteFailed(fileName: url.lastPathComponent)
        }

        logger.info("File written: fileName=\(url.lastPathComponent, privacy: .public)")
    }

    /// 循环写入直到全部数据落盘；写入中途失败抛错。
    private static func writeAll(fileDescriptor: Int32, data: Data) throws
    {
        try data.withUnsafeBytes { rawBuffer in
            var remaining = rawBuffer.count
            var offset = 0
            while remaining > 0
            {
                let base = rawBuffer.baseAddress?.advanced(by: offset)
                let written = Darwin.write(fileDescriptor, base, remaining)
                if written == -1
                {
                    throw AutoSaveError.fileWriteFailed(fileName: "")
                }
                remaining -= written
                offset += written
            }
        }
    }
}
