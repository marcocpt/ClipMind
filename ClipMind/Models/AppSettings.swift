import Foundation

struct AppSettings: Codable, Equatable {
    /// F1.10：默认全局快捷键（应用代码中默认值的唯一来源）。
    /// 通用设置视图与快捷键录制器重置按钮通过引用本常量获取默认值。
    static let defaultHotkey = "cmd+shift+space"

    /// F1.10：历史默认快捷键（用于老用户迁移检查）。
    /// 仅当持久化值等于本常量时，迁移为新默认值。
    static let legacyDefaultHotkey = "cmd+shift+v"

    var apiProvider: APIProvider?
    var apiKey: String?
    var sensitiveDetectionEnabled: Bool = true
    var appBlacklist: [String] = []
    var autoCleanupEnabled: Bool = true
    var cleanupDays: Int = 30
    var launchAtLogin: Bool = true
    var hotkey: String = AppSettings.defaultHotkey

    /// 成员逐一初始化器（显式声明以保留默认值语义）。
    ///
    /// 定义 `init(userDefaults:)` 后编译器不再自动对外暴露 memberwise init，
    /// 因此显式提供本初始化器以兼容现有调用点（如 `AppSettings()`、
    /// `AppSettings(autoCleanupEnabled:cleanupDays:)`、
    /// `AppSettings(apiProvider:apiKey:...)`）。
    init(
        apiProvider: APIProvider? = nil,
        apiKey: String? = nil,
        sensitiveDetectionEnabled: Bool = true,
        appBlacklist: [String] = [],
        autoCleanupEnabled: Bool = true,
        cleanupDays: Int = 30,
        launchAtLogin: Bool = true,
        hotkey: String = AppSettings.defaultHotkey
    ) {
        self.apiProvider = apiProvider
        self.apiKey = apiKey
        self.sensitiveDetectionEnabled = sensitiveDetectionEnabled
        self.appBlacklist = appBlacklist
        self.autoCleanupEnabled = autoCleanupEnabled
        self.cleanupDays = cleanupDays
        self.launchAtLogin = launchAtLogin
        self.hotkey = hotkey
    }

    /// 从 UserDefaults 读取持久化值构造应用设置。
    ///
    /// 用于应用启动时读取用户自定义配置。若 UserDefaults 中无对应键，
    /// 使用与默认初始化器一致的默认值。
    ///
    /// `apiProvider` 从 UserDefaults 读取（与 `APIKeyManager` 一致）；
    /// `apiKey` 不读取，保持 nil（API Key 由 `APIKeyManager` 通过 Keychain 管理，
    /// 不应通过 UserDefaults 暴露）。
    /// - Parameter userDefaults: UserDefaults 实例，默认为 `.standard`
    init(userDefaults: UserDefaults = .standard) {
        self.apiProvider = userDefaults.string(forKey: "apiProvider").flatMap(APIProvider.init)
        self.apiKey = nil
        self.sensitiveDetectionEnabled = userDefaults.object(forKey: "sensitiveDetectionEnabled") as? Bool ?? true
        self.appBlacklist = (userDefaults.array(forKey: "appBlacklist") as? [String]) ?? []
        self.autoCleanupEnabled = userDefaults.object(forKey: "autoCleanupEnabled") as? Bool ?? true
        self.cleanupDays = userDefaults.object(forKey: "cleanupDays") as? Int ?? 30
        self.launchAtLogin = userDefaults.object(forKey: "launchAtLogin") as? Bool ?? true
        self.hotkey = userDefaults.string(forKey: "hotkey") ?? Self.defaultHotkey
    }

    /// F1.10：老用户旧默认值迁移检查。
    ///
    /// 仅当 `hotkey` 等于 `legacyDefaultHotkey` 时，迁移为 `defaultHotkey`；
    /// 其他值（自定义值、新默认值、空值、无效值）不修改。
    /// 迁移检查是幂等的：已是新默认值时不会再次迁移。
    /// 迁移成功时同步写回 UserDefaults，确保下次启动不再触发迁移。
    /// - Parameter userDefaults: 用于持久化的 UserDefaults 实例，默认为 `.standard`
    /// - Returns: 是否发生了迁移（用于日志记录与可观测性）
    @discardableResult
    mutating func migrateLegacyHotkey(userDefaults: UserDefaults = .standard) -> Bool {
        guard hotkey == Self.legacyDefaultHotkey else {
            return false
        }
        hotkey = Self.defaultHotkey
        userDefaults.set(hotkey, forKey: "hotkey")
        LogCategory.app.info("迁移事件: type=legacyHotkeyMigration, action=legacyToCurrent")
        return true
    }
}
