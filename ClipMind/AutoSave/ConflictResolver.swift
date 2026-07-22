import Foundation

/// 冲突处理器（文件已存在时追加数字后缀递增）。
public struct ConflictResolver
{
    public static let defaultMaxAttempts = 999

    private let maxAttempts: Int

    public init(maxAttempts: Int = Self.defaultMaxAttempts)
    {
        self.maxAttempts = maxAttempts
    }

    public func resolve(_ url: URL) throws -> URL
    {
        let fileManager = FileManager.default

        if !fileManager.fileExists(atPath: url.path)
        {
            return url
        }

        let directory = url.deletingLastPathComponent()
        let originalName = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension

        for attempt in 1...maxAttempts
        {
            let candidateName = "\(originalName)-\(attempt).\(ext)"
            let candidateURL = directory.appendingPathComponent(candidateName)
            if !fileManager.fileExists(atPath: candidateURL.path)
            {
                return candidateURL
            }
        }

        throw AutoSaveError.fileNameConflictExhausted
    }
}
