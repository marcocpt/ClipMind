import Foundation

/// 文件名生成器（D9 8 步单一确定顺序，与需求文档 FR-006/D9 严格一致）。
public struct FileNameGenerator
{
    /// 非法字符集合（D9 步骤 4）：换行符、路径分隔符、文件系统特殊字符、Markdown 链接字符。
    /// 注意：`.` 的首尾去除在步骤 5 处理。
    private static let illegalCharacters: Set<Character> = [
        "\n", "\r", "\t",
        "/", "\\",
        ":", "*", "?", "\"", "<", ">", "|",
        "[", "]"
    ]

    public init() {}

    /// 生成候选文件名（D9 步骤 1~7，步骤 8 由调用方 ConflictResolver 完成）。
    public func generate(
        content: String,
        appName: String,
        fileFormat: FileFormat,
        fileNameLength: Int,
        timestamp: Date
    ) -> String
    {
        // 步骤 1：读取内容（content 已传入）

        // 步骤 2：标准化换行与空白（CRLF → LF，连续空白折叠为单个空格）
        let lineNormalized = content
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let collapsed = Self.collapseWhitespace(lineNormalized)

        // 步骤 3：取前 N 个用户可见字符（按 Character 组合字符簇计算）
        let prefix = String(collapsed.prefix(fileNameLength))

        // 步骤 4：过滤非法字符
        let filtered = prefix.filter { !Self.illegalCharacters.contains($0) }

        // 步骤 5：去除首尾空白与首尾的点
        var trimmed = filtered.trimmingCharacters(in: .whitespacesAndNewlines)
        while trimmed.hasPrefix(".")
        {
            trimmed.removeFirst()
        }
        while trimmed.hasSuffix(".")
        {
            trimmed.removeLast()
        }

        // 步骤 6：为空时使用备用文件名 clip-{timestamp}（毫秒时间戳，保证并发唯一性）
        let baseName: String
        if trimmed.isEmpty
        {
            let millis = Int(timestamp.timeIntervalSince1970 * 1000)
            baseName = "clip-\(millis)"
        } else
        {
            baseName = trimmed
        }

        // 步骤 7：添加扩展名
        let ext = fileFormat.fileExtension
        return "\(baseName).\(ext)"

        // 步骤 8：交给冲突处理器（由调用方 ConflictResolver 完成，见 FR-007）
    }

    /// 折叠连续空白为单个空格（D9 步骤 2）。
    private static func collapseWhitespace(_ text: String) -> String
    {
        var result = ""
        var lastWasWhitespace = false
        for char in text
        {
            if char.isWhitespace
            {
                if !lastWasWhitespace
                {
                    result.append(" ")
                    lastWasWhitespace = true
                }
            } else
            {
                result.append(char)
                lastWasWhitespace = false
            }
        }
        return result
    }
}
