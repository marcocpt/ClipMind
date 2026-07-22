import Foundation

/// F2.1 配置快照（D6 配置快照不可变，D23 异步执行期间不读实时配置）。
///
/// 在捕获事件构造阶段从 `AutoSaveSettingsStore` 读取当前配置并打包进 `CaptureEvent`。
/// 异步 F2.1 流程只读取此快照，避免配置在异步执行期间被修改导致行为不一致。
public struct F2xConfigSnapshot: Sendable, Equatable
{
    public let isEnabled: Bool
    public let saveDirectory: String
    public let whitelistBundleIds: [String]
    public let fileFormat: FileFormat
    public let lengthThreshold: Int
    public let fileNameLength: Int
    public let sensitiveFilterEnabled: Bool
    public let pathFormat: PathFormat

    public init(
        isEnabled: Bool,
        saveDirectory: String,
        whitelistBundleIds: [String],
        fileFormat: FileFormat,
        lengthThreshold: Int,
        fileNameLength: Int,
        sensitiveFilterEnabled: Bool,
        pathFormat: PathFormat
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

    /// 从 `AutoSaveSettings` 构造快照（D23 事件构造阶段读取）。
    public init(from settings: AutoSaveSettings)
    {
        self.isEnabled = settings.isEnabled
        self.saveDirectory = settings.saveDirectory
        self.whitelistBundleIds = settings.whitelistBundleIds
        self.fileFormat = settings.fileFormat
        self.lengthThreshold = settings.lengthThreshold
        self.fileNameLength = settings.fileNameLength
        self.sensitiveFilterEnabled = settings.sensitiveFilterEnabled
        self.pathFormat = settings.pathFormat
    }

    /// 判断 bundleId 是否在白名单中。
    public func isWhitelisted(bundleId: String) -> Bool
    {
        whitelistBundleIds.contains(bundleId)
    }
}
