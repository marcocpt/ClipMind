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
}
