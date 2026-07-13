import Foundation

/// 默认黑名单（T3.4）
///
/// 提供预置的黑名单条目，覆盖密码管理器和银行业务应用。
/// 设计规范 4.3 节和 12.4 节定义的 7 个默认条目：
/// - 1Password（密码管理器）
/// - 钥匙串访问（系统密码管理）
/// - 工商银行、招商银行、建设银行、农业银行、中国银行（银行业务）
enum DefaultBlacklist {
    /// 默认黑名单条目（7 个）
    static let entries: [BlacklistEntry] = createEntries()

    /// 创建默认黑名单条目
    /// - Returns: 7 个预置 BlacklistEntry 实例
    static func createEntries() -> [BlacklistEntry] {
        let now = Date()
        return [
            BlacklistEntry(
                id: UUID(), bundleId: "com.agilebits.onepassword-os",
                appName: "1Password", addedAt: now, isDefault: true
            ),
            BlacklistEntry(
                id: UUID(), bundleId: "com.apple.keychainaccess",
                appName: "钥匙串访问", addedAt: now, isDefault: true
            ),
            BlacklistEntry(
                id: UUID(), bundleId: "com.icbc.*",
                appName: "工商银行", addedAt: now, isDefault: true
            ),
            BlacklistEntry(
                id: UUID(), bundleId: "com.cmb.*",
                appName: "招商银行", addedAt: now, isDefault: true
            ),
            BlacklistEntry(
                id: UUID(), bundleId: "com.chinaccb.*",
                appName: "建设银行", addedAt: now, isDefault: true
            ),
            BlacklistEntry(
                id: UUID(), bundleId: "com.abchina.*",
                appName: "农业银行", addedAt: now, isDefault: true
            ),
            BlacklistEntry(
                id: UUID(), bundleId: "com.boc.*",
                appName: "中国银行", addedAt: now, isDefault: true
            )
        ]
    }
}
