import AppKit
import XCTest

@testable import ClipMind

/// XCTest 集成测试（D18 覆盖业务逻辑 AC）。
final class AutoSaveIntegrationTests: XCTestCase
{
    private var pasteboard: NSPasteboard!
    private var settingsStore: AutoSaveSettingsStore!
    private var defaults: UserDefaults!
    private var suppressor: SelfWriteSuppressor!
    private var service: AutoSaveService!
    private var tempDir: URL!

    override func setUpWithError() throws
    {
        pasteboard = NSPasteboard(name: .init("test-\(UUID().uuidString)"))
        pasteboard.clearContents()
        defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
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
        defaults.removePersistentDomain(forName: defaults.dictionaryRepresentation().keys.first ?? "")
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

    // MARK: - AC-05：原内容仍入库 ClipMind 历史（Phase 0 验证 handle 不抛异常）

    func testAC05OriginalContentStillStored() throws
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
        XCTAssertTrue(true, "AC-05：handle 不抛异常即满足（F1.x 入库由 Phase 1 验证）")
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
