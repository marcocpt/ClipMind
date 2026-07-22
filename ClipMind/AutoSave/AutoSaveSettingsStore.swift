import Foundation

/// F2.1 自动保存配置持久化（UserDefaults + 范围校验 + 白名单去重 + 变更通知）。
public final class AutoSaveSettingsStore
{
    public static let didChangeNotification = Notification.Name("ClipMindAutoSaveSettingsDidChange")

    private let defaults: UserDefaults

    private enum Keys
    {
        static let isEnabled = "F2.1.autoSave.isEnabled"
        static let saveDirectory = "F2.1.autoSave.saveDirectory"
        static let whitelistBundleIds = "F2.1.autoSave.whitelistBundleIds"
        static let fileFormat = "F2.1.autoSave.fileFormat"
        static let lengthThreshold = "F2.1.autoSave.lengthThreshold"
        static let fileNameLength = "F2.1.autoSave.fileNameLength"
        static let sensitiveFilterEnabled = "F2.1.autoSave.sensitiveFilterEnabled"
        static let pathFormat = "F2.1.autoSave.pathFormat"
    }

    public init(defaults: UserDefaults = .standard)
    {
        self.defaults = defaults
    }

    public func load() -> AutoSaveSettings
    {
        let isEnabled = defaults.object(forKey: Keys.isEnabled) as? Bool ?? false
        let saveDirectory = defaults.string(forKey: Keys.saveDirectory)
            ?? AutoSaveSettings.defaultSaveDirectory
        let whitelistBundleIds = defaults.array(forKey: Keys.whitelistBundleIds) as? [String]
            ?? AutoSaveSettings.defaultWhitelist
        let fileFormatRaw = defaults.string(forKey: Keys.fileFormat) ?? FileFormat.markdown.rawValue
        let fileFormat = FileFormat(rawValue: fileFormatRaw) ?? .markdown
        let lengthThreshold = defaults.object(forKey: Keys.lengthThreshold) as? Int ?? 50
        let fileNameLength = defaults.object(forKey: Keys.fileNameLength) as? Int ?? 20
        let sensitiveFilterEnabled = defaults.object(forKey: Keys.sensitiveFilterEnabled) as? Bool ?? true
        let pathFormatRaw = defaults.string(forKey: Keys.pathFormat) ?? PathFormat.plainPath.rawValue
        let pathFormat = PathFormat(rawValue: pathFormatRaw) ?? .plainPath

        return AutoSaveSettings(
            isEnabled: isEnabled,
            saveDirectory: saveDirectory,
            whitelistBundleIds: Array(Set(whitelistBundleIds)),
            fileFormat: fileFormat,
            lengthThreshold: clamped(lengthThreshold, range: AutoSaveSettings.lengthThresholdRange),
            fileNameLength: clamped(fileNameLength, range: AutoSaveSettings.fileNameLengthRange),
            sensitiveFilterEnabled: sensitiveFilterEnabled,
            pathFormat: pathFormat
        )
    }

    public func save(_ settings: AutoSaveSettings)
    {
        let dedupedWhitelist = Array(Set(settings.whitelistBundleIds))
        let clampedThreshold = clamped(settings.lengthThreshold, range: AutoSaveSettings.lengthThresholdRange)
        let clampedFileNameLength = clamped(settings.fileNameLength, range: AutoSaveSettings.fileNameLengthRange)

        defaults.set(settings.isEnabled, forKey: Keys.isEnabled)
        defaults.set(settings.saveDirectory, forKey: Keys.saveDirectory)
        defaults.set(dedupedWhitelist, forKey: Keys.whitelistBundleIds)
        defaults.set(settings.fileFormat.rawValue, forKey: Keys.fileFormat)
        defaults.set(clampedThreshold, forKey: Keys.lengthThreshold)
        defaults.set(clampedFileNameLength, forKey: Keys.fileNameLength)
        defaults.set(settings.sensitiveFilterEnabled, forKey: Keys.sensitiveFilterEnabled)
        defaults.set(settings.pathFormat.rawValue, forKey: Keys.pathFormat)

        // D15：日志仅输出 isEnabled 字段，不输出敏感信息或用户输入内容。
        LogCategory.storage.logger.info("Config saved: isEnabled=\(settings.isEnabled, privacy: .public)")

        NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
    }

    private func clamped(_ value: Int, range: ClosedRange<Int>) -> Int
    {
        min(max(value, range.lowerBound), range.upperBound)
    }
}
