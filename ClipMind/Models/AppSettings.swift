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

    /// F1.10：老用户旧默认值迁移检查。
    ///
    /// 仅当 `hotkey` 等于 `legacyDefaultHotkey` 时，迁移为 `defaultHotkey`；
    /// 其他值（自定义值、新默认值、空值、无效值）不修改。
    /// 迁移检查是幂等的：已是新默认值时不会再次迁移。
    mutating func migrateLegacyHotkey() {
        guard hotkey == Self.legacyDefaultHotkey else {
            return
        }
        hotkey = Self.defaultHotkey
        LogCategory.app.info("已迁移旧默认快捷键为新默认值")
    }
}
