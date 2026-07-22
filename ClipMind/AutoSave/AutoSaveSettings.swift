import Foundation

/// 文件格式枚举（C-02）。
public enum FileFormat: String, Codable, Sendable, CaseIterable
{
    case markdown
    case plainText

    public var fileExtension: String
    {
        switch self
        {
        case .markdown:
            return "md"
        case .plainText:
            return "txt"
        }
    }

    public var displayName: String
    {
        switch self
        {
        case .markdown:
            return "Markdown (.md)"
        case .plainText:
            return "纯文本 (.txt)"
        }
    }
}

/// 路径格式枚举（C-03，D16 URI 编码）。
public enum PathFormat: String, Codable, Sendable, CaseIterable
{
    case plainPath
    case fileURI
    case markdownLink

    public var displayName: String
    {
        switch self
        {
        case .plainPath:
            return "纯路径"
        case .fileURI:
            return "file:// URI"
        case .markdownLink:
            return "Markdown 链接"
        }
    }
}

/// F2.1 自动保存配置模型（D11 总开关默认关闭）。
public struct AutoSaveSettings: Codable, Equatable, Sendable
{
    public var isEnabled: Bool
    public var saveDirectory: String
    public var whitelistBundleIds: [String]
    public var fileFormat: FileFormat
    public var lengthThreshold: Int
    public var fileNameLength: Int
    public var sensitiveFilterEnabled: Bool
    public var pathFormat: PathFormat

    /// 文件路径是否进入 ClipMind 历史条目（默认开，可拖拽文件路径）。
    /// 开启时，F2.1 保存文件后将文件路径以 ClipContent.filePath 存入历史；
    /// 关闭时，历史中只有原始内容条目，无文件路径条目。
    public var showFilePathInHistory: Bool

    public static let lengthThresholdRange = 1...10000
    public static let fileNameLengthRange = 1...50

    /// 解析字符串为 Int，越界夹紧到 range 边界，空值/非数字/空白回退到 fallback。
    /// 决策 C2（夹紧到边界）+ C3（空值/非数字回退到当前值）。
    /// - Parameters:
    ///   - text: 用户输入字符串
    ///   - range: 合法范围闭区间
    ///   - fallback: 解析失败时的回退值
    /// - Returns: 夹紧后的整数
    public static func clampedInt(_ text: String, range: ClosedRange<Int>, fallback: Int) -> Int
    {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let value = Int(trimmed) else
        {
            return fallback
        }
        return min(max(value, range.lowerBound), range.upperBound)
    }

    public static let defaultWhitelist: [String] = [
        "com.apple.Safari",
        "com.google.Chrome",
        "com.trae.ide",
        "com.microsoft.VSCode",
        "com.apple.dt.Xcode"
    ]

    public static let defaultSaveDirectory = "~/Documents/ClipMind/Clips/"

    public init(
        isEnabled: Bool = false,
        saveDirectory: String = AutoSaveSettings.defaultSaveDirectory,
        whitelistBundleIds: [String] = AutoSaveSettings.defaultWhitelist,
        fileFormat: FileFormat = .markdown,
        lengthThreshold: Int = 50,
        fileNameLength: Int = 20,
        sensitiveFilterEnabled: Bool = true,
        pathFormat: PathFormat = .plainPath,
        showFilePathInHistory: Bool = true
    )
    {
        self.isEnabled = isEnabled
        self.saveDirectory = saveDirectory
        self.whitelistBundleIds = whitelistBundleIds
        self.fileFormat = fileFormat
        self.lengthThreshold = lengthThreshold
        self.fileNameLength = fileNameLength
        self.sensitiveFilterEnabled = sensitiveFilterEnabled
        self.pathFormat = pathFormat
        self.showFilePathInHistory = showFilePathInHistory
    }
}
