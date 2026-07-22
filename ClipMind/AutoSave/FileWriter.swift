import CryptoKit
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
            try createDirectoryIfNeeded(directory: directory, fileManager: fileManager)
        }

        // D10：O_EXCL 原子创建 + D14：0600 权限（POSIX open 一步到位）
        let data = Data(content.utf8)
        let fileDescriptor = url.path.withCString { pathCString in
            open(pathCString, O_CREAT | O_EXCL | O_WRONLY, Self.filePermissions)
        }

        if fileDescriptor == -1
        {
            try handleOpenFailure(errnoValue: errno, url: url)
        }

        defer {
            close(fileDescriptor)
        }

        // 写入数据；失败时清理半成品文件（D10）
        do {
            try Self.writeAll(fileDescriptor: fileDescriptor, data: data)
        } catch {
            try? fileManager.removeItem(at: url)
            logger.error("Write failed, cleaned up: pathHash=\(Self.pathHash(url.path), privacy: .public)")
            throw AutoSaveError.fileWriteFailed
        }

        logger.info("File written: pathHash=\(Self.pathHash(url.path), privacy: .public)")
    }

    private func createDirectoryIfNeeded(directory: URL, fileManager: FileManager) throws
    {
        do {
            try fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o755]
            )
        } catch {
            logger.error("""
            Directory creation failed: errorCode=\(error._code, privacy: .public) \
            pathHash=\(Self.pathHash(directory.path), privacy: .public)
            """)
            throw AutoSaveError.directoryCreationFailed
        }
    }

    /// 处理 open 失败：按 errno 分级抛出对应错误（D13）。
    private func handleOpenFailure(errnoValue: Int32, url: URL) throws
    {
        let pathHash = Self.pathHash(url.path)
        switch errnoValue
        {
        case EEXIST:
            logger.error("""
            File exists: errno=\(errnoValue, privacy: .public) \
            pathHash=\(pathHash, privacy: .public)
            """)
            throw AutoSaveError.fileAlreadyExists
        case EACCES, EPERM:
            logger.error("""
            Permission denied: errno=\(errnoValue, privacy: .public) \
            pathHash=\(pathHash, privacy: .public)
            """)
            throw AutoSaveError.permissionDenied
        case ENOSPC:
            logger.error("""
            Disk full: errno=\(errnoValue, privacy: .public) \
            pathHash=\(pathHash, privacy: .public)
            """)
            throw AutoSaveError.diskFull
        default:
            logger.error("""
            Open failed: errno=\(errnoValue, privacy: .public) \
            pathHash=\(pathHash, privacy: .public)
            """)
            throw AutoSaveError.fileWriteFailed
        }
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
                    throw AutoSaveError.fileWriteFailed
                }
                remaining -= written
                offset += written
            }
        }
    }

    /// 计算路径哈希（SHA-256 前 8 位），用于日志标识文件而不泄露用户名/内容前缀（NFR-007/D15）。
    static func pathHash(_ path: String) -> String
    {
        let digest = SHA256.hash(data: Data(path.utf8))
        return digest.prefix(4).map { String(format: "%02x", $0) }.joined()
    }
}
