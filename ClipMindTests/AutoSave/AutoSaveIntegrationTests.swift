import AppKit
import XCTest

@testable import ClipMind

/// XCTest 集成测试（D18 覆盖业务逻辑 AC）。
final class AutoSaveIntegrationTests: XCTestCase
{
    private var pasteboard: NSPasteboard!
    private var settingsStore: AutoSaveSettingsStore!
    private var defaults: UserDefaults!
    private var suiteName: String!
    private var suppressor: SelfWriteSuppressor!
    private var service: AutoSaveService!
    private var tempDir: URL!

    override func setUpWithError() throws
    {
        pasteboard = NSPasteboard(name: .init("test-\(UUID().uuidString)"))
        pasteboard.clearContents()
        suiteName = "test-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        settingsStore = AutoSaveSettingsStore(defaults: defaults)
        suppressor = SelfWriteSuppressor()

        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        var settings = settingsStore.load()
        settings.isEnabled = true
        settings.saveDirectory = tempDir.path + "/"
        settings.lengthThreshold = 10
        settingsStore.save(settings)

        service = AutoSaveService(
            settingsStore: settingsStore,
            pasteboard: pasteboard,
            suppressor: suppressor
        )
    }

    override func tearDownWithError() throws
    {
        try? FileManager.default.removeItem(at: tempDir)
        defaults.removePersistentDomain(forName: suiteName)
    }

    // MARK: - AC-01：白名单 App 复制长内容触发自动保存

    func testAC01WhitelistAppTriggersAutoSave() throws
    {
        pasteboard.clearContents()
        pasteboard.setString(String(repeating: "a", count: 100), forType: .string)
        let changeCount = pasteboard.changeCount

        let event = CaptureEvent(
            changeCount: changeCount,
            content: .text(String(repeating: "a", count: 100)),
            bundleId: "com.apple.Safari",
            appName: "Safari",
            blacklisted: false,
            sensitiveResult: .none,
            f1xConfigSnapshot: F1xConfigSnapshot(blacklistBundleIds: []),
            f2xConfigSnapshot: F2xConfigSnapshot(from: settingsStore.load())
        )

        service.handle(event: event)
        waitForQueue()

        let files = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
        XCTAssertEqual(files.count, 1, "AC-01：应创建 1 个文件")
    }

    // MARK: - AC-05：原内容仍入库 ClipMind 历史（Phase 0 验证 handle 不破坏配置）
    // F1.x 入库由 Phase 1 集成，Phase 0 验证 handle 不修改 settingsStore 配置、不抛异常。

    func testAC05HandleDoesNotBreakSettingsStore() throws
    {
        pasteboard.clearContents()
        pasteboard.setString(String(repeating: "a", count: 100), forType: .string)
        let changeCount = pasteboard.changeCount

        let configBefore = settingsStore.load()
        let event = CaptureEvent(
            changeCount: changeCount,
            content: .text(String(repeating: "a", count: 100)),
            bundleId: "com.apple.Safari",
            appName: "Safari",
            blacklisted: false,
            sensitiveResult: .none,
            f1xConfigSnapshot: F1xConfigSnapshot(blacklistBundleIds: []),
            f2xConfigSnapshot: F2xConfigSnapshot(from: configBefore)
        )

        service.handle(event: event)
        waitForQueue()

        let configAfter = settingsStore.load()
        XCTAssertEqual(configAfter.isEnabled, configBefore.isEnabled, "AC-05：handle 不应修改 isEnabled")
        XCTAssertEqual(configAfter.saveDirectory, configBefore.saveDirectory, "AC-05：handle 不应修改 saveDirectory")
        XCTAssertEqual(configAfter.lengthThreshold, configBefore.lengthThreshold, "AC-05：handle 不应修改 lengthThreshold")
        XCTAssertEqual(
            configAfter.sensitiveFilterEnabled,
            configBefore.sensitiveFilterEnabled,
            "AC-05：handle 不应修改 sensitiveFilterEnabled"
        )
    }

    // MARK: - AC-14：关闭敏感过滤后敏感内容可保存

    func testAC14SensitiveContentSavedWhenFilterDisabled() throws
    {
        var settings = settingsStore.load()
        settings.sensitiveFilterEnabled = false
        settingsStore.save(settings)

        pasteboard.clearContents()
        let sensitiveText = "password=123456 very long content to pass threshold"
        pasteboard.setString(sensitiveText, forType: .string)
        let changeCount = pasteboard.changeCount

        let event = CaptureEvent(
            changeCount: changeCount,
            content: .text(sensitiveText),
            bundleId: "com.apple.Safari",
            appName: "Safari",
            blacklisted: false,
            sensitiveResult: SensitiveMatchResult(isSensitive: true, matchedPatterns: ["password"]),
            f1xConfigSnapshot: F1xConfigSnapshot(blacklistBundleIds: []),
            f2xConfigSnapshot: F2xConfigSnapshot(from: settingsStore.load())
        )

        service.handle(event: event)
        waitForQueue()

        let files = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
        XCTAssertEqual(files.count, 1, "AC-14：关闭敏感过滤后应保存敏感内容")

        let savedContent = try String(contentsOf: files[0], encoding: .utf8)
        XCTAssertEqual(savedContent, sensitiveText, "AC-14：文件内容应为原始敏感内容")
    }

    // MARK: - AC-08：禁用总开关不触发保存

    func testAC08DisabledSwitchDoesNotSave() throws
    {
        var settings = settingsStore.load()
        settings.isEnabled = false
        settingsStore.save(settings)

        let event = CaptureEvent(
            changeCount: 100,
            content: .text(String(repeating: "a", count: 100)),
            bundleId: "com.apple.Safari",
            appName: "Safari",
            blacklisted: false,
            sensitiveResult: .none,
            f1xConfigSnapshot: F1xConfigSnapshot(blacklistBundleIds: []),
            f2xConfigSnapshot: F2xConfigSnapshot(from: settingsStore.load())
        )

        service.handle(event: event)
        waitForQueue()

        let files = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
        XCTAssertTrue(files.isEmpty, "AC-08：禁用总开关不应创建文件")
    }

    // MARK: - AC-18：自我写入抑制不回环

    func testAC18SelfWriteSuppressionNoLoop() throws
    {
        pasteboard.clearContents()
        pasteboard.setString(String(repeating: "a", count: 100), forType: .string)
        let changeCount = pasteboard.changeCount

        let event = CaptureEvent(
            changeCount: changeCount,
            content: .text(String(repeating: "a", count: 100)),
            bundleId: "com.apple.Safari",
            appName: "Safari",
            blacklisted: false,
            sensitiveResult: .none,
            f1xConfigSnapshot: F1xConfigSnapshot(blacklistBundleIds: []),
            f2xConfigSnapshot: F2xConfigSnapshot(from: settingsStore.load())
        )

        service.handle(event: event)
        waitForQueue()

        let newChangeCount = pasteboard.changeCount
        XCTAssertTrue(suppressor.checkAndReset(changeCount: newChangeCount), "AC-18：应标记新 changeCount")
    }

    // MARK: - AC-20：不可变快照契约

    func testAC20ImmutableSnapshotContract() throws
    {
        let event = CaptureEventFixtures.longTextEvent(threshold: 10)
        let originalConfig = event.f2xConfigSnapshot

        var settings = settingsStore.load()
        settings.isEnabled = false
        settingsStore.save(settings)

        XCTAssertEqual(event.f2xConfigSnapshot.isEnabled, originalConfig.isEnabled, "AC-20：快照不可变")
        XCTAssertTrue(event.f2xConfigSnapshot.isEnabled, "AC-20：原快照仍为启用状态")
    }

    private func waitForQueue()
    {
        let expectation = XCTestExpectation(description: "等待队列完成")
        service.queue.async { expectation.fulfill() }
        wait(for: [expectation], timeout: 2.0)
    }
}
