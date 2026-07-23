import Foundation

/// 文件名生成器（D9 8 步单一确定顺序，与需求文档 FR-006/D9 严格一致）。
public struct FileNameGenerator
{
    /// 需替换为下划线的特殊字符集合（D9 步骤 4）：
    /// - 路径分隔符与文件系统特殊字符
    /// - Markdown 格式符号
    /// - Shell 特殊字符
    /// - 中文与英文标点符号
    /// 注意：`.` 与 `-` 保留（文件名常用）；空格保留（步骤 2 已折叠）；
    /// `\n \r \t` 由步骤 2 标准化为空格，此处不再列出。
    private static let specialCharacters: Set<Character> = [
        // 路径分隔符
        "/", "\\",
        // 文件系统特殊字符
        ":", "*", "?", "\"", "<", ">", "|",
        // Markdown 格式符号
        "#", "`", "~", "[", "]",
        // Shell 特殊字符
        "%", "&", ";", "$", "(", ")", "{", "}", "'", "!",
        // 中文标点
        "，", "。", "、", "；", "：", "！", "？",
        "\u{201C}", "\u{201D}", "\u{2018}", "\u{2019}",
        "（", "）", "【", "】", "《", "》", "—", "…", "·",
        // 英文标点（不含 . 和 -）
        ",", ";", ":", "!", "?", "'", "(", ")"
    ]

    /// 首尾修剪字符集：空白、点、下划线（D9 步骤 5）。
    private static let trimCharacterSet = CharacterSet.whitespacesAndNewlines
        .union(CharacterSet(charactersIn: "._"))

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

        // 步骤 4：将特殊字符替换为下划线（保留分隔语义，D9 步骤 4）
        let replaced = Self.replaceSpecialCharacters(prefix)

        // 步骤 4.5：折叠连续下划线为单个下划线（D9 步骤 4.5）
        let underscoreCollapsed = Self.collapseUnderscores(replaced)

        // 步骤 5：去除首尾空白、首尾的点与首尾下划线
        let trimmed = underscoreCollapsed.trimmingCharacters(in: Self.trimCharacterSet)

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

    /// 将特殊字符替换为下划线（D9 步骤 4）。
    private static func replaceSpecialCharacters(_ text: String) -> String
    {
        let chars = text.map { specialCharacters.contains($0) ? "_" : $0 }
        return String(chars)
    }

    /// 折叠连续下划线为单个下划线（D9 步骤 4.5）。
    private static func collapseUnderscores(_ text: String) -> String
    {
        var result = ""
        var lastWasUnderscore = false
        for char in text
        {
            if char == "_"
            {
                if !lastWasUnderscore
                {
                    result.append(char)
                    lastWasUnderscore = true
                }
            } else
            {
                result.append(char)
                lastWasUnderscore = false
            }
        }
        return result
    }
}
