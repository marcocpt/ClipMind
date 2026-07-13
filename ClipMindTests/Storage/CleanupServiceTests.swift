@testable import ClipMind
import XCTest

/// CleanupService 单元测试（T3.3）
///
/// 覆盖 AC-21（30 天前内容自动清理）中 EncryptedStoreTests 未覆盖的用例：
/// - TC-21-02：29 天前内容不被清理
/// - TC-21-03：应用启动时自动触发清理
final class CleanupServiceTests: XCTestCase {
    private var dbPath: URL!
    private var store: EncryptedStore!
    private var service: CleanupService!

    override func setUpWithError() throws {
        dbPath = try TestDatabaseHelper.makeTempDBPath()
        store = try EncryptedStore(
            dbPath: dbPath,
            key: TestDatabaseHelper.makeTestKey()
        )
        service = CleanupService(store: store, settings: AppSettings())
    }

    override func tearDownWithError() throws {
        service.stopPeriodicCleanup()
        service = nil
        store = nil
        if let dbPath {
            TestDatabaseHelper.cleanup(at: dbPath)
        }
        dbPath = nil
    }

    // MARK: - TC-21-02：29 天前内容不被清理

    func testCleanupKeeps29DayOldItems() throws {
        let item = makeItemWithAge(days: 29, text: "29天前")
        try store.save(item)

        try service.performCleanup()

        let loaded = try store.loadAll()
        XCTAssertEqual(loaded.count, 1, "29 天前的内容不应被清理")
        XCTAssertEqual(loaded.first?.id, item.id)
    }

    // MARK: - TC-21-03：应用启动时自动触发清理

    func testCleanupOnLaunchDeletesOldItems() throws {
        let oldItem = makeItemWithAge(days: 31, text: "31天前")
        try store.save(oldItem)
        let newItem = ClipItem.makeText(
            "新内容",
            contentType: .article,
            sourceApp: "com.test.app",
            sourceAppName: "TestApp"
        )
        try store.save(newItem)

        service.cleanupOnLaunch()

        let loaded = try store.loadAll()
        XCTAssertEqual(loaded.count, 1, "启动清理后应只剩 1 条新记录")
        XCTAssertEqual(loaded.first?.id, newItem.id, "应保留新记录")
    }

    func testCleanupOnLaunchWithEmptyDatabaseDoesNotThrow() {
        // 空数据库启动清理不应崩溃
        service.cleanupOnLaunch()
    }

    // MARK: - autoCleanupEnabled 关闭时不清理

    func testNoCleanupWhenAutoCleanupDisabled() throws {
        let settings = AppSettings(autoCleanupEnabled: false, cleanupDays: 30)
        service = CleanupService(store: store, settings: settings)

        let oldItem = makeItemWithAge(days: 31, text: "31天前")
        try store.save(oldItem)

        try service.performCleanup()

        let loaded = try store.loadAll()
        XCTAssertEqual(loaded.count, 1, "autoCleanupEnabled=false 时不应清理")
    }

    func testCleanupOnLaunchSkipsWhenDisabled() throws {
        let settings = AppSettings(autoCleanupEnabled: false, cleanupDays: 30)
        service = CleanupService(store: store, settings: settings)

        let oldItem = makeItemWithAge(days: 31, text: "31天前")
        try store.save(oldItem)

        service.cleanupOnLaunch()

        let loaded = try store.loadAll()
        XCTAssertEqual(loaded.count, 1, "autoCleanupEnabled=false 时启动不应清理")
    }

    // MARK: - 自定义清理周期

    func testCustomCleanupDaysRespected() throws {
        let settings = AppSettings(autoCleanupEnabled: true, cleanupDays: 7)
        service = CleanupService(store: store, settings: settings)

        let eightDayItem = makeItemWithAge(days: 8, text: "8天前")
        try store.save(eightDayItem)
        let fiveDayItem = makeItemWithAge(days: 5, text: "5天前")
        try store.save(fiveDayItem)

        try service.performCleanup()

        let loaded = try store.loadAll()
        XCTAssertEqual(loaded.count, 1, "8 天前的应被清理（周期 7 天），5 天前的应保留")
        XCTAssertEqual(loaded.first?.id, fiveDayItem.id)
    }

    // MARK: - 辅助方法

    /// 创建指定天数前时间戳的 ClipItem
    private func makeItemWithAge(days: Int, text: String) -> ClipItem {
        let base = ClipItem.makeText(
            text,
            contentType: .article,
            sourceApp: "com.test.app",
            sourceAppName: "TestApp"
        )
        return ClipItem(
            id: base.id,
            content: base.content,
            contentType: base.contentType,
            sourceApp: base.sourceApp,
            sourceAppName: base.sourceAppName,
            timestamp: Date().addingTimeInterval(-Double(days) * 24 * 3600),
            summary: base.summary,
            translation: base.translation,
            rewrite: base.rewrite,
            todos: base.todos,
            embeddings: base.embeddings
        )
    }
}
