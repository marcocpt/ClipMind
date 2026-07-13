@testable import ClipMind
import Foundation
import XCTest

/// BlacklistService 单元测试（T3.2）
final class BlacklistServiceTests: XCTestCase {
    /// 测试用 UserDefaults（隔离标准 UserDefaults）
    private var testDefaults: UserDefaults!
    private var testSuiteName: String!
    private var service: BlacklistService!

    // MARK: - 生命周期

    override func setUpWithError() throws {
        testSuiteName = "BlacklistServiceTests-\(UUID().uuidString)"
        testDefaults = UserDefaults(suiteName: testSuiteName)!
        service = BlacklistService(defaults: testDefaults)
    }

    override func tearDownWithError() throws {
        if let suiteName = testSuiteName {
            UserDefaults().removePersistentDomain(forName: suiteName)
        }
        testDefaults = nil
        testSuiteName = nil
        service = nil
    }

    // MARK: - 添加条目后可查询到

    func testAddBlacklistEntry() {
        let entry = BlacklistEntry(
            id: UUID(),
            bundleId: "com.example.app",
            appName: "Example",
            addedAt: Date(),
            isDefault: false
        )

        service.add(entry)

        XCTAssertTrue(service.contains(bundleId: "com.example.app"), "添加后应能查询到该条目")
        let all = service.getAll()
        XCTAssertEqual(all.count, 1, "应有 1 条记录")
        XCTAssertEqual(all.first?.bundleId, "com.example.app")
    }

    // MARK: - 移除条目后不再匹配

    func testRemoveBlacklistEntry() {
        let id = UUID()
        let entry = BlacklistEntry(
            id: id,
            bundleId: "com.example.remove",
            appName: "RemoveApp",
            addedAt: Date(),
            isDefault: false
        )
        service.add(entry)
        XCTAssertTrue(service.contains(bundleId: "com.example.remove"))

        service.remove(id: id)

        XCTAssertFalse(service.contains(bundleId: "com.example.remove"), "移除后不应再匹配")
        XCTAssertTrue(service.getAll().isEmpty, "条目列表应为空")
    }

    // MARK: - bundleId 精确匹配

    func testContainsByBundleId() {
        let entry = BlacklistEntry(
            id: UUID(),
            bundleId: "com.test.exact",
            appName: "ExactApp",
            addedAt: Date(),
            isDefault: false
        )
        service.add(entry)

        XCTAssertTrue(service.contains(bundleId: "com.test.exact"), "精确 bundleId 应匹配")
        XCTAssertFalse(service.contains(bundleId: "com.test.exact2"), "不同 bundleId 不应匹配")
        XCTAssertFalse(service.contains(bundleId: "com.test"), "前缀不应匹配")
    }

    // MARK: - 通配符匹配

    func testContainsWithWildcardBundleId() {
        let entry = BlacklistEntry(
            id: UUID(),
            bundleId: "com.icbc.*",
            appName: "工商银行",
            addedAt: Date(),
            isDefault: false
        )
        service.add(entry)

        // 通配符应匹配带后缀的 bundleId
        XCTAssertTrue(service.contains(bundleId: "com.icbc.macbank"), "应匹配 com.icbc.macbank")
        XCTAssertTrue(service.contains(bundleId: "com.icbc.iphone"), "应匹配 com.icbc.iphone")
        XCTAssertTrue(service.contains(bundleId: "com.icbc.app"), "应匹配 com.icbc.app")

        // 通配符不应匹配无后缀的 bundleId
        XCTAssertFalse(service.contains(bundleId: "com.icbc"), "不应匹配无后缀的 com.icbc")
        // 不应匹配其他前缀
        XCTAssertFalse(service.contains(bundleId: "com.icbcx.app"), "不应匹配 com.icbcx.app")
        XCTAssertFalse(service.contains(bundleId: "com.other.app"), "不应匹配其他前缀")
    }

    // MARK: - 获取全部条目

    func testGetAllReturnsAllEntries() {
        let entry1 = BlacklistEntry(
            id: UUID(),
            bundleId: "com.test.one",
            appName: "One",
            addedAt: Date(),
            isDefault: false
        )
        let entry2 = BlacklistEntry(
            id: UUID(),
            bundleId: "com.test.two",
            appName: "Two",
            addedAt: Date(),
            isDefault: false
        )
        service.add(entry1)
        service.add(entry2)

        let all = service.getAll()
        XCTAssertEqual(all.count, 2, "应有 2 条记录")
        XCTAssertTrue(all.contains(entry1), "应包含 entry1")
        XCTAssertTrue(all.contains(entry2), "应包含 entry2")
    }

    // MARK: - 自定义条目 isDefault=false

    func testAddCustomEntry() {
        service.addCustom(bundleId: "com.custom.app", appName: "自定义应用")

        let all = service.getAll()
        XCTAssertEqual(all.count, 1, "应有 1 条自定义记录")
        let entry = all.first
        XCTAssertEqual(entry?.bundleId, "com.custom.app")
        XCTAssertEqual(entry?.appName, "自定义应用")
        XCTAssertFalse(entry?.isDefault ?? true, "自定义条目 isDefault 应为 false")
    }

    // MARK: - 新实例从 UserDefaults 加载已保存数据

    func testPersistenceAcrossInstances() {
        service.addCustom(bundleId: "com.persist.app", appName: "持久化应用")

        // 创建新实例，应从 UserDefaults 加载已保存的数据
        let newService = BlacklistService(defaults: testDefaults)

        XCTAssertTrue(newService.contains(bundleId: "com.persist.app"), "新实例应加载已持久化的数据")
        XCTAssertEqual(newService.getAll().count, 1, "新实例应有 1 条记录")
    }

    // MARK: - 移除默认条目

    func testRemoveDefaultEntry() {
        let defaultId = UUID()
        let defaultEntry = BlacklistEntry(
            id: defaultId,
            bundleId: "com.default.app",
            appName: "默认应用",
            addedAt: Date(),
            isDefault: true
        )
        let customId = UUID()
        let customEntry = BlacklistEntry(
            id: customId,
            bundleId: "com.custom.app",
            appName: "自定义应用",
            addedAt: Date(),
            isDefault: false
        )
        service.add(defaultEntry)
        service.add(customEntry)
        XCTAssertEqual(service.getAll().count, 2)

        // 移除默认条目
        service.removeDefault(id: defaultId)

        XCTAssertFalse(service.contains(bundleId: "com.default.app"), "默认条目应被移除")
        XCTAssertTrue(service.contains(bundleId: "com.custom.app"), "自定义条目应保留")
        XCTAssertEqual(service.getAll().count, 1, "应剩余 1 条记录")
    }

    // MARK: - 空黑名单不匹配任何 bundleId

    func testEmptyBlacklistReturnsFalse() {
        XCTAssertFalse(service.contains(bundleId: "com.any.app"), "空黑名单不应匹配任何 bundleId")
        XCTAssertTrue(service.getAll().isEmpty, "初始状态应为空")
    }

    // MARK: - 默认黑名单集成

    func testDefaultBlacklistEntriesDetected() {
        for entry in DefaultBlacklist.entries {
            service.add(entry)
        }

        // 精确匹配
        XCTAssertTrue(
            service.contains(bundleId: "com.agilebits.onepassword-os"),
            "应匹配 1Password"
        )
        XCTAssertTrue(
            service.contains(bundleId: "com.apple.keychainaccess"),
            "应匹配钥匙串访问"
        )

        // 通配符匹配
        XCTAssertTrue(service.contains(bundleId: "com.icbc.macbank"), "应匹配工商银行")
        XCTAssertTrue(service.contains(bundleId: "com.cmb.client"), "应匹配招商银行")
        XCTAssertTrue(service.contains(bundleId: "com.chinaccb.app"), "应匹配建设银行")
        XCTAssertTrue(service.contains(bundleId: "com.abchina.phone"), "应匹配农业银行")
        XCTAssertTrue(service.contains(bundleId: "com.boc.mobile"), "应匹配中国银行")

        // 非默认条目不应匹配
        XCTAssertFalse(service.contains(bundleId: "com.random.app"), "不应匹配随机应用")
    }
}
