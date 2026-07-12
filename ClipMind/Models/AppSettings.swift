import Foundation

struct AppSettings: Codable, Equatable {
    var apiProvider: APIProvider?
    var apiKey: String?
    var sensitiveDetectionEnabled: Bool = true
    // swiftlint:disable:next inclusive_language
    var appBlacklist: [String] = []
    var autoCleanupEnabled: Bool = true
    var cleanupDays: Int = 30
    var launchAtLogin: Bool = true
    var hotkey: String = "cmd+shift+v"
}
