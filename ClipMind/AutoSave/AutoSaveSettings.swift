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

    public static let lengthThresholdRange = 1...10000
    public static let fileNameLengthRange = 1...50

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
        pathFormat: PathFormat = .plainPath
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
    }
}
