import Foundation

/// 黑名单管理服务（T3.2）
///
/// 管理应用黑名单条目的增删查，支持 bundleId 精确匹配和通配符匹配。
/// 使用 UserDefaults 持久化黑名单数据（JSON 编码 BlacklistEntry 数组）。
final class BlacklistService {
    /// UserDefaults 键名
    static let storageKey = "appBlacklist"

    /// 通配符后缀
    private static let wildcardSuffix = ".*"

    /// UserDefaults 实例（支持注入用于测试）
    private let defaults: UserDefaults

    /// 内存中的黑名单条目
    private var entries: [BlacklistEntry]

    /// 初始化
    /// - Parameter defaults: UserDefaults 实例，默认为 .standard
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.entries = Self.load(from: defaults)
    }

    /// 添加黑名单条目
    /// - Parameter entry: 待添加的黑名单条目
    func add(_ entry: BlacklistEntry) {
        entries.append(entry)
        save()
    }

    /// 移除黑名单条目
    /// - Parameter id: 待移除条目的 UUID
    func remove(id: UUID) {
        entries.removeAll { $0.id == id }
        save()
    }

    /// 检查 bundleId 是否在黑名单中
    /// - Parameter bundleId: 待检查的 bundleId
    /// - Returns: true 表示在黑名单中（支持通配符匹配）
    func contains(bundleId: String) -> Bool {
        entries.contains { matches($0.bundleId, bundleId) }
    }

    /// 获取全部黑名单条目
    /// - Returns: 黑名单条目数组
    func getAll() -> [BlacklistEntry] {
        entries
    }

    /// 添加自定义黑名单条目（isDefault=false）
    /// - Parameters:
    ///   - bundleId: 应用 bundleId（支持通配符，如 com.icbc.*）
    ///   - appName: 应用名称
    func addCustom(bundleId: String, appName: String) {
        let entry = BlacklistEntry(
            id: UUID(),
            bundleId: bundleId,
            appName: appName,
            addedAt: Date(),
            isDefault: false
        )
        add(entry)
    }

    /// 移除默认黑名单条目
    /// - Parameter id: 待移除的默认条目 UUID
    func removeDefault(id: UUID) {
        entries.removeAll { $0.id == id && $0.isDefault }
        save()
    }
}

// MARK: - 持久化

private extension BlacklistService {
    /// 从 UserDefaults 加载黑名单条目
    /// - Parameter defaults: UserDefaults 实例
    /// - Returns: 黑名单条目数组，加载失败时返回空数组
    static func load(from defaults: UserDefaults) -> [BlacklistEntry] {
        guard let data = defaults.data(forKey: storageKey) else {
            return []
        }
        return (try? JSONDecoder().decode([BlacklistEntry].self, from: data)) ?? []
    }

    /// 保存黑名单条目到 UserDefaults
    func save() {
        guard let data = try? JSONEncoder().encode(entries) else {
            return
        }
        defaults.set(data, forKey: Self.storageKey)
    }
}

// MARK: - 通配符匹配

private extension BlacklistService {
    /// 检查 bundleId 是否匹配模式
    /// - Parameters:
    ///   - pattern: 黑名单模式（支持通配符 com.icbc.*）
    ///   - bundleId: 待检查的 bundleId
    /// - Returns: true 表示匹配
    func matches(_ pattern: String, _ bundleId: String) -> Bool {
        if pattern.hasSuffix(Self.wildcardSuffix) {
            // 通配符模式：com.icbc.* 匹配 com.icbc.xxx（需有后缀）
            let prefix = String(pattern.dropLast(Self.wildcardSuffix.count))
            return bundleId.hasPrefix("\(prefix).")
        }
        return pattern == bundleId
    }
}
