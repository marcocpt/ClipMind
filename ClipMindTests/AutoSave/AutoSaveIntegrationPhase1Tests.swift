import AppKit
import CryptoKit
import XCTest

@testable import ClipMind

final class AutoSaveIntegrationPhase1Tests: XCTestCase
{
    private var pasteboard: NSPasteboard!
    private var watcher: PasteboardWatcher!
    private var store: EncryptedStore!
    private var captureService: ClipCaptureService!
    private var autoSaveService: AutoSaveService!
    private var suppressor: SelfWriteSuppressor!
    private var settingsStore: AutoSaveSettingsStore!
    private var eventBuilder: CaptureEventBuilder!
    private var defaults: UserDefaults!
    private var tempDir: URL!
    private var saveDir: URL!

    override func setUpWithError() throws
    {
        pasteboard = NSPasteboard(name: .init("test-int-\(UUID().uuidString)"))
        pasteboard.clearContents()

        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let dbPath = tempDir.appendingPathComponent("test_int.db")
        let key = SymmetricKey(size: .bits256)
        store = try EncryptedStore(dbPath: dbPath, key: key)

        defaults = UserDefaults(suiteName: "test-int-\(UUID().uuidString)")!
        settingsStore = AutoSaveSettingsStore(defaults: defaults)

        saveDir = tempDir.appendingPathComponent("saves")
        try FileManager.default.createDirectory(at: saveDir, withIntermediateDirectories: true)

        // 配置自动保存
        var settings = AutoSaveSettings()
        settings.isEnabled = true
        settings.saveDirectory = saveDir.path + "/"
        settings.lengthThreshold = 50
        settings.sensitiveFilterEnabled = true
        settings.whitelistBundleIds = ["com.test.whitelisted"]
        settingsStore.save(settings)

        suppressor = SelfWriteSuppressor()
        autoSaveService = AutoSaveService(
            settingsStore: settingsStore,
            pasteboard: pasteboard,
            suppressor: suppressor
        )

        eventBuilder = CaptureEventBuilder(
            appDetector: AppDetector(),
            sensitiveDetector: SensitiveDetector(defaults: defaults),
            blacklistService: BlacklistService(defaults: defaults),
            settingsStore: settingsStore
        )

        watcher = PasteboardWatcher(pasteboard: pasteboard, eventBuilder: eventBuilder)
        let embeddingService = LocalEmbeddingService()
        let classifier = ClassificationService(embeddingService: embeddingService)
        captureService = ClipCaptureService(watcher: watcher, store: store, classifier: classifier)
        captureService.autoSaveService = autoSaveService
    }

    override func tearDownWithError() throws
    {
        captureService?.stop()
        watcher?.stopWatching()
        if let tempDir = tempDir
        {
            try? FileManager.default.removeItem(at: tempDir)
        }
    }

    // MARK: - AC-01（XCTest 部分）：白名单 App 复制长内容端到端

    func testAC01EndToEndAutoSave() throws
    {
        // 由于 AppDetector 在测试环境返回 "unknown"，直接注入事件
        let longContent = String(repeating: "a", count: 100)
        let event = CaptureEvent(
            id: UUID().uuidString,
            changeCount: pasteboard.changeCount,
            content: .text(longContent),
            bundleId: "com.test.whitelisted",
            appName: "TestApp",
            blacklisted: false,
            sensitiveResult: .none,
            f1xConfigSnapshot: F1xConfigSnapshot(blacklistBundleIds: []),
            f2xConfigSnapshot: F2xConfigSnapshot(from: settingsStore.load()),
            timestamp: Date()
        )

        captureService.handleCaptureEvent(event)

        // 等待异步保存完成
        let expectation = XCTestExpectation(description: "文件应被保存")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0)
        {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)

        // 验证文件已保存
        let files = try FileManager.default.contentsOfDirectory(at: saveDir, includingPropertiesForKeys: nil)
        XCTAssertTrue(files.contains { $0.pathExtension == "md" }, "应保存 .md 文件")

        // 验证原内容入库
        let items = try store.loadAll()
        XCTAssertEqual(items.count, 1, "原内容应入库")
    }

    // MARK: - AC-08（XCTest 部分）：禁用总开关不触发保存

    func testAC08DisabledNoSave() throws
    {
        var settings = settingsStore.load()
        settings.isEnabled = false
        settingsStore.save(settings)

        let longContent = String(repeating: "b", count: 100)
        let event = CaptureEvent(
            id: UUID().uuidString,
            changeCount: pasteboard.changeCount,
            content: .text(longContent),
            bundleId: "com.test.whitelisted",
            appName: "TestApp",
            blacklisted: false,
            sensitiveResult: .none,
            f1xConfigSnapshot: F1xConfigSnapshot(blacklistBundleIds: []),
            f2xConfigSnapshot: F2xConfigSnapshot(from: settingsStore.load()),
            timestamp: Date()
        )

        captureService.handleCaptureEvent(event)

        let expectation = XCTestExpectation(description: "等待异步检查")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0)
        {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)

        // 验证无文件保存
        let files = try FileManager.default.contentsOfDirectory(at: saveDir, includingPropertiesForKeys: nil)
        XCTAssertTrue(files.isEmpty, "总开关关闭时不应保存文件")

        // 验证原内容仍入库
        let items = try store.loadAll()
        XCTAssertEqual(items.count, 1, "禁用总开关时原内容仍应入库")
    }

    // MARK: - AC-14（XCTest 部分）：关闭敏感过滤后敏感内容可保存

    func testAC14SensitiveFilterDisabledSavesSensitive() throws
    {
        var settings = settingsStore.load()
        settings.sensitiveFilterEnabled = false
        settingsStore.save(settings)

        let sensitiveContent = "password=supersecret " + String(repeating: "x", count: 50)
        let event = CaptureEvent(
            id: UUID().uuidString,
            changeCount: pasteboard.changeCount,
            content: .text(sensitiveContent),
            bundleId: "com.test.whitelisted",
            appName: "TestApp",
            blacklisted: false,
            sensitiveResult: SensitiveMatchResult(isSensitive: true, matchedPatterns: ["password"]),
            f1xConfigSnapshot: F1xConfigSnapshot(blacklistBundleIds: []),
            f2xConfigSnapshot: F2xConfigSnapshot(from: settingsStore.load()),
            timestamp: Date()
        )

        // F1.x 分支：敏感命中不入库（ClipCaptureService 在敏感命中时直接返回）
        captureService.handleCaptureEvent(event)

        // F2.1 分支：敏感过滤关闭时保存。
        // 注：ClipCaptureService 敏感命中提前返回不派发 F2.1（任务 3 既定设计），
        // 故此处直接调用 AutoSaveService.handle 验证 F2.1 分支独立行为。
        autoSaveService.handle(event: event)

        let expectation = XCTestExpectation(description: "等待异步保存")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0)
        {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)

        // 验证 F2.1 分支保存了敏感内容（敏感过滤关闭）
        let files = try FileManager.default.contentsOfDirectory(at: saveDir, includingPropertiesForKeys: nil)
        XCTAssertTrue(files.contains { $0.pathExtension == "md" }, "敏感过滤关闭时应保存文件")

        // 验证 F1.x 分支未入库（敏感命中）
        let items = try store.loadAll()
        XCTAssertEqual(items.count, 0, "F1.x 敏感命中不入库")
    }

    // MARK: - AC-06（XCTest 部分）：敏感过滤开启时不保存

    func testAC06SensitiveFilterEnabledNoSave() throws
    {
        let sensitiveContent = "password=supersecret " + String(repeating: "x", count: 50)
        let event = CaptureEvent(
            id: UUID().uuidString,
            changeCount: pasteboard.changeCount,
            content: .text(sensitiveContent),
            bundleId: "com.test.whitelisted",
            appName: "TestApp",
            blacklisted: false,
            sensitiveResult: SensitiveMatchResult(isSensitive: true, matchedPatterns: ["password"]),
            f1xConfigSnapshot: F1xConfigSnapshot(blacklistBundleIds: []),
            f2xConfigSnapshot: F2xConfigSnapshot(from: settingsStore.load()),
            timestamp: Date()
        )

        captureService.handleCaptureEvent(event)

        let expectation = XCTestExpectation(description: "等待异步检查")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0)
        {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)

        // 验证无文件保存
        let files = try FileManager.default.contentsOfDirectory(at: saveDir, includingPropertiesForKeys: nil)
        XCTAssertTrue(files.isEmpty, "敏感过滤开启时不应保存敏感内容")

        // 验证 F1.x 未入库
        let items = try store.loadAll()
        XCTAssertEqual(items.count, 0, "F1.x 敏感命中不入库")
    }
}
