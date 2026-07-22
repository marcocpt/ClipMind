import AppKit
import XCTest

@testable import ClipMind

final class AutoSaveServiceTests: XCTestCase
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

    // MARK: - TC-UT-53：F2.1 禁用时不触发保存（D11）

    func testDisabledF2xDoesNotSave() throws
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
        XCTAssertTrue(files.isEmpty, "F2.1 禁用时不应创建文件")
    }

    // MARK: - TC-UT-54：黑名单 App 不触发保存（D3 黑名单优先）

    func testBlacklistedAppDoesNotSave() throws
    {
        let event = CaptureEventFixtures.blacklistedAppEvent()
        service.handle(event: event)
        waitForQueue()

        let files = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
        XCTAssertTrue(files.isEmpty, "黑名单 App 不应触发 F2.1")
    }

    // MARK: - TC-UT-55：非白名单 App 不触发保存

    func testNonWhitelistedAppDoesNotSave() throws
    {
        let event = CaptureEvent(
            changeCount: 100,
            content: .text(String(repeating: "a", count: 100)),
            bundleId: "com.unknown.app",
            appName: "Unknown",
            blacklisted: false,
            sensitiveResult: .none,
            f1xConfigSnapshot: F1xConfigSnapshot(blacklistBundleIds: []),
            f2xConfigSnapshot: F2xConfigSnapshot(from: settingsStore.load())
        )

        service.handle(event: event)
        waitForQueue()

        let files = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
        XCTAssertTrue(files.isEmpty, "非白名单 App 不应触发 F2.1")
    }

    // MARK: - TC-UT-56：内容长度不足不触发保存

    func testShortContentDoesNotSave() throws
    {
        var settings = settingsStore.load()
        settings.lengthThreshold = 100
        settingsStore.save(settings)

        let shortEvent = CaptureEvent(
            changeCount: 101,
            content: .text("short"),
            bundleId: "com.apple.Safari",
            appName: "Safari",
            blacklisted: false,
            sensitiveResult: .none,
            f1xConfigSnapshot: F1xConfigSnapshot(blacklistBundleIds: []),
            f2xConfigSnapshot: F2xConfigSnapshot(from: settingsStore.load())
        )

        service.handle(event: shortEvent)
        waitForQueue()

        let files = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
        XCTAssertTrue(files.isEmpty, "内容长度不足不应触发 F2.1")
    }

    // MARK: - TC-UT-57：成功保存并替换剪贴板（AC-01/06/13）

    func testSuccessfulSaveAndReplace() throws
    {
        pasteboard.clearContents()
        pasteboard.setString("original long content", forType: .string)
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
        XCTAssertEqual(files.count, 1, "应创建 1 个文件")
        XCTAssertTrue(files[0].pathExtension == "md")

        let replaced = pasteboard.string(forType: .string) ?? ""
        XCTAssertTrue(replaced.contains(tempDir.path) || replaced.hasPrefix("file://"), "剪贴板应替换为文件路径")
    }

    // MARK: - TC-UT-58：敏感内容跳过保存（D2 + sensitiveFilterEnabled）

    func testSensitiveContentSkipped() throws
    {
        let event = CaptureEventFixtures.sensitiveContentEvent()
        service.handle(event: event)
        waitForQueue()

        let files = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
        XCTAssertTrue(files.isEmpty, "敏感内容应跳过保存")
    }

    // MARK: - TC-UT-59：changeCount 过期不重试（D24）

    func testExpiredChangeCountDoesNotRetry() throws
    {
        pasteboard.clearContents()
        pasteboard.setString("original", forType: .string)

        let event = CaptureEvent(
            changeCount: 999,
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

        XCTAssertEqual(pasteboard.string(forType: .string), "original", "changeCount 过期时剪贴板不应被替换")
    }

    // MARK: - TC-UT-60：图片内容不触发保存（D12）

    func testImageContentDoesNotSave() throws
    {
        let event = CaptureEvent(
            changeCount: 200,
            content: .image(Data()),
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
        XCTAssertTrue(files.isEmpty, "图片内容不应触发 F2.1（D12）")
    }

    // MARK: - TC-UT-60b：纯空白内容不触发保存（D12 纯空白检查）

    func testBlankOnlyContentDoesNotSave() throws
    {
        let blankText = String(repeating: " ", count: 100) + "\n\t\r"
        let event = CaptureEvent(
            changeCount: 201,
            content: .text(blankText),
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
        XCTAssertTrue(files.isEmpty, "纯空白内容不应触发 F2.1（D12）")
    }

    private func waitForQueue()
    {
        let expectation = XCTestExpectation(description: "等待队列完成")
        service.queue.async { expectation.fulfill() }
        wait(for: [expectation], timeout: 2.0)
    }
}
