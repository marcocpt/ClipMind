import AppKit
import CryptoKit
import XCTest

@testable import ClipMind

final class ClipCaptureServiceEventTests: XCTestCase
{
    private var pasteboard: NSPasteboard!
    private var watcher: PasteboardWatcher!
    private var store: EncryptedStore!
    private var service: ClipCaptureService!
    private var eventBuilder: CaptureEventBuilder!
    private var defaults: UserDefaults!
    private var tempDir: URL!

    override func setUpWithError() throws
    {
        pasteboard = NSPasteboard(name: .init("test-svc-\(UUID().uuidString)"))
        pasteboard.clearContents()

        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let dbPath = tempDir.appendingPathComponent("test_svc.db")
        let key = SymmetricKey(size: .bits256)
        store = try EncryptedStore(dbPath: dbPath, key: key)

        defaults = UserDefaults(suiteName: "test-svc-\(UUID().uuidString)")!
        let settingsStore = AutoSaveSettingsStore(defaults: defaults)
        eventBuilder = CaptureEventBuilder(
            appDetector: AppDetector(),
            sensitiveDetector: SensitiveDetector(defaults: defaults),
            blacklistService: BlacklistService(defaults: defaults),
            settingsStore: settingsStore
        )

        watcher = PasteboardWatcher(pasteboard: pasteboard, eventBuilder: eventBuilder)
        let embeddingService = LocalEmbeddingService()
        let classifier = ClassificationService(embeddingService: embeddingService)
        service = ClipCaptureService(watcher: watcher, store: store, classifier: classifier)
    }

    override func tearDownWithError() throws
    {
        service?.stop()
        watcher?.stopWatching()
        if let tempDir = tempDir
        {
            try? FileManager.default.removeItem(at: tempDir)
        }
    }

    // MARK: - TC-UT-61：普通内容正常入库（AC-05）

    func testNormalContentStored() throws
    {
        let expectation = XCTestExpectation(description: "内容应入库")
        service.onClipStored = { _ in expectation.fulfill() }

        pasteboard.clearContents()
        pasteboard.setString("普通文本内容用于入库测试", forType: .string)
        watcher.handlePasteboardChange()

        wait(for: [expectation], timeout: 2.0)

        let items = try store.loadAll()
        XCTAssertEqual(items.count, 1, "普通内容应入库")
    }

    // MARK: - TC-UT-62：黑名单命中不入库（D3）

    func testBlacklistedContentNotStored() throws
    {
        // 由于测试环境无法控制前台 App，通过直接调用 handleCaptureEvent 测试
        let event = CaptureEvent(
            id: UUID().uuidString,
            changeCount: 100,
            content: .text("黑名单测试内容"),
            bundleId: "com.test.blacklisted",
            appName: "BlacklistedApp",
            blacklisted: true,
            sensitiveResult: .none,
            f1xConfigSnapshot: F1xConfigSnapshot(blacklistBundleIds: ["com.test.blacklisted"]),
            f2xConfigSnapshot: F2xConfigSnapshot(
                isEnabled: false,
                saveDirectory: "",
                whitelistBundleIds: [],
                fileFormat: .markdown,
                lengthThreshold: 50,
                fileNameLength: 20,
                sensitiveFilterEnabled: true,
                pathFormat: .plainPath,
                showFilePathInHistory: true
            ),
            timestamp: Date()
        )

        service.handleCaptureEvent(event)

        let items = try store.loadAll()
        XCTAssertEqual(items.count, 0, "黑名单内容不应入库")
    }

    // MARK: - TC-UT-63：敏感命中不入库（AC-06）

    func testSensitiveContentNotStored() throws
    {
        let event = CaptureEvent(
            id: UUID().uuidString,
            changeCount: 101,
            content: .text("password=secret123"),
            bundleId: "com.test.app",
            appName: "TestApp",
            blacklisted: false,
            sensitiveResult: SensitiveMatchResult(isSensitive: true, matchedPatterns: ["password"]),
            f1xConfigSnapshot: F1xConfigSnapshot(blacklistBundleIds: []),
            f2xConfigSnapshot: F2xConfigSnapshot(
                isEnabled: false,
                saveDirectory: "",
                whitelistBundleIds: [],
                fileFormat: .markdown,
                lengthThreshold: 50,
                fileNameLength: 20,
                sensitiveFilterEnabled: true,
                pathFormat: .plainPath,
                showFilePathInHistory: true
            ),
            timestamp: Date()
        )

        service.handleCaptureEvent(event)

        let items = try store.loadAll()
        XCTAssertEqual(items.count, 0, "敏感内容不应入库")
    }

    // MARK: - TC-UT-64：autoSaveService 为 nil 时 F1.x 行为不变（D22）

    func testNilAutoSaveServicePreservesF1xBehavior() throws
    {
        XCTAssertNil(service.autoSaveService, "autoSaveService 默认应为 nil")

        let expectation = XCTestExpectation(description: "应正常入库")
        service.onClipStored = { _ in expectation.fulfill() }

        pasteboard.clearContents()
        pasteboard.setString("nil autoSave 测试内容", forType: .string)
        watcher.handlePasteboardChange()

        wait(for: [expectation], timeout: 2.0)

        let items = try store.loadAll()
        XCTAssertEqual(items.count, 1, "autoSaveService=nil 时应正常入库")
    }

    // MARK: - TC-UT-65：autoSaveService 存在时调用 handle(event:)（D7）

    func testAutoSaveServiceHandleCalled() throws
    {
        let mockService = MockAutoSaveService()
        service.autoSaveService = mockService

        let expectation = XCTestExpectation(description: "入库完成")
        service.onClipStored = { _ in expectation.fulfill() }

        pasteboard.clearContents()
        pasteboard.setString("autoSave 派发测试内容", forType: .string)
        watcher.handlePasteboardChange()

        wait(for: [expectation], timeout: 2.0)

        XCTAssertEqual(mockService.handleCallCount, 1, "autoSaveService.handle 应被调用一次")
        let items = try store.loadAll()
        XCTAssertEqual(items.count, 1, "autoSaveService 存在时原内容仍应入库")
    }
}

// MARK: - Mock

private final class MockAutoSaveService: AutoSaveServiceProtocol
{
    private(set) var handleCallCount = 0
    private(set) var lastEvent: CaptureEvent?

    func handle(event: CaptureEvent)
    {
        handleCallCount += 1
        lastEvent = event
    }
}
