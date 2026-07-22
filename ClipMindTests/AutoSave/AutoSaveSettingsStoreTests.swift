import XCTest

@testable import ClipMind

final class AutoSaveSettingsStoreTests: XCTestCase
{
    private var defaults: UserDefaults!
    private var store: AutoSaveSettingsStore!

    override func setUpWithError() throws
    {
        defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        store = AutoSaveSettingsStore(defaults: defaults)
    }

    // MARK: - TC-UT-20：默认加载（D11 总开关关闭）

    func testLoadDefaults() throws
    {
        let settings = store.load()
        XCTAssertFalse(settings.isEnabled, "D11：默认总开关关闭")
        XCTAssertEqual(settings.saveDirectory, AutoSaveSettings.defaultSaveDirectory)
        XCTAssertEqual(settings.fileFormat, .markdown)
    }

    // MARK: - TC-UT-21：保存与重新加载

    func testSaveAndReload() throws
    {
        var settings = store.load()
        settings.isEnabled = true
        settings.saveDirectory = "/tmp/clips/"
        settings.lengthThreshold = 100
        store.save(settings)

        let reloaded = store.load()
        XCTAssertTrue(reloaded.isEnabled)
        XCTAssertEqual(reloaded.saveDirectory, "/tmp/clips/")
        XCTAssertEqual(reloaded.lengthThreshold, 100)
    }

    // MARK: - TC-UT-22：范围校验（lengthThreshold 超出上限被截断）

    func testLengthThresholdClamped() throws
    {
        var settings = store.load()
        settings.lengthThreshold = 99999
        store.save(settings)

        let reloaded = store.load()
        XCTAssertEqual(reloaded.lengthThreshold, 10000, "超出上限应被截断到 10000")
    }

    // MARK: - TC-UT-23：白名单去重

    func testWhitelistDeduplication() throws
    {
        var settings = store.load()
        settings.whitelistBundleIds = ["com.apple.Safari", "com.apple.Safari", "com.google.Chrome"]
        store.save(settings)

        let reloaded = store.load()
        XCTAssertEqual(Set(reloaded.whitelistBundleIds).count, 2, "重复项应被去重")
    }

    // MARK: - TC-UT-24：配置变更通知

    func testConfigChangeNotification() throws
    {
        let expectation = XCTestExpectation(description: "应发送配置变更通知")
        let observer = NotificationCenter.default.addObserver(
            forName: AutoSaveSettingsStore.didChangeNotification,
            object: nil,
            queue: nil
        ) { _ in
            expectation.fulfill()
        }

        defer
        {
            NotificationCenter.default.removeObserver(observer)
        }

        var settings = store.load()
        settings.isEnabled = true
        store.save(settings)

        wait(for: [expectation], timeout: 1.0)
    }
}
