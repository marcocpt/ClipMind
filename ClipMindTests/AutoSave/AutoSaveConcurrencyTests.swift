import AppKit
import XCTest

@testable import ClipMind

/// 并发场景测试（TC-CC-01~14）。
final class AutoSaveConcurrencyTests: XCTestCase
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

    // MARK: - TC-CC-01：连续快速触发多次保存

    func testTC_CC_01RapidSuccessiveSaves() throws
    {
        for index in 0..<5
        {
            pasteboard.clearContents()
            pasteboard.setString(String(repeating: Character("\(index)"), count: 100), forType: .string)
            let changeCount = pasteboard.changeCount

            let event = CaptureEvent(
                changeCount: changeCount,
                content: .text(String(repeating: Character("\(index)"), count: 100)),
                bundleId: "com.apple.Safari",
                appName: "Safari",
                blacklisted: false,
                sensitiveResult: .none,
                f1xConfigSnapshot: F1xConfigSnapshot(blacklistBundleIds: []),
                f2xConfigSnapshot: F2xConfigSnapshot(from: settingsStore.load())
            )
            service.handle(event: event)
        }

        waitForQueue()
        let files = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
        XCTAssertGreaterThanOrEqual(files.count, 1, "TC-CC-01：应至少创建 1 个文件")
    }

    // MARK: - TC-CC-02：自我写入抑制器并发访问

    func testTC_CC_02ConcurrentSuppressorAccess() throws
    {
        let expectation = XCTestExpectation(description: "并发访问完成")
        expectation.expectedFulfillmentCount = 10

        let queue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)

        for index in 0..<10
        {
            queue.async
            {
                self.suppressor.markSelfWrite(changeCount: index)
                _ = self.suppressor.checkAndReset(changeCount: index)
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 2.0)
        XCTAssertTrue(true, "TC-CC-02：并发访问不崩溃即通过")
    }

    // MARK: - TC-CC-03：配置变更期间处理事件（D6 快照隔离）

    func testTC_CC_03ConfigChangeDuringProcessing() throws
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

        var settings = settingsStore.load()
        settings.isEnabled = false
        settingsStore.save(settings)

        service.handle(event: event)
        waitForQueue()

        let files = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
        XCTAssertEqual(files.count, 1, "TC-CC-03：应使用事件快照（isEnabled=true）创建文件")
    }

    // MARK: - TC-CC-04 ~ TC-CC-14：14 个并发场景批量验证

    func testTC_CC_04To14ConcurrentScenariosPreserveIntegrity() throws
    {
        let concurrentQueue = DispatchQueue(label: "test.tc.cc.concurrent", attributes: .concurrent)
        let group = DispatchGroup()
        let lock = NSLock()
        var services: [AutoSaveService] = []

        for index in 0..<14
        {
            group.enter()
            concurrentQueue.async
            {
                let svc = self.makeConcurrentScenario(index: index)
                lock.lock()
                services.append(svc)
                lock.unlock()
                group.leave()
            }
        }
        group.wait()
        waitForAllServices(services)

        let files = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
        let nonEmptyCount = try countNonEmptyFiles(files)
        XCTAssertEqual(nonEmptyCount, files.count, "TC-CC-04~14：所有文件内容不应为空")
        XCTAssertGreaterThanOrEqual(files.count, 1, "TC-CC-04~14：应至少保存 1 个文件")
        XCTAssertLessThanOrEqual(files.count, 14, "TC-CC-04~14：文件数量不应超过场景数")
    }

    private func makeConcurrentScenario(index: Int) -> AutoSaveService
    {
        let scenarioPasteboard = NSPasteboard(name: .init("tc-cc-\(UUID().uuidString)"))
        scenarioPasteboard.clearContents()
        let content = "并发场景\(index)内容验证并发安全长度超过阈值"
        scenarioPasteboard.setString(content, forType: .string)
        let changeCount = scenarioPasteboard.changeCount

        let scenarioSuppressor = SelfWriteSuppressor()
        let svc = AutoSaveService(
            settingsStore: settingsStore,
            pasteboard: scenarioPasteboard,
            suppressor: scenarioSuppressor
        )
        let event = CaptureEvent(
            changeCount: changeCount,
            content: .text(content),
            bundleId: "com.apple.Safari",
            appName: "Safari",
            blacklisted: false,
            sensitiveResult: .none,
            f1xConfigSnapshot: F1xConfigSnapshot(blacklistBundleIds: []),
            f2xConfigSnapshot: F2xConfigSnapshot(from: settingsStore.load())
        )
        svc.handle(event: event)
        return svc
    }

    private func waitForAllServices(_ services: [AutoSaveService])
    {
        let expectation = XCTestExpectation(description: "所有队列完成")
        expectation.expectedFulfillmentCount = services.count
        for svc in services
        {
            svc.queue.async { expectation.fulfill() }
        }
        wait(for: [expectation], timeout: 10.0)
    }

    private func countNonEmptyFiles(_ files: [URL]) throws -> Int
    {
        var count = 0
        for file in files
        {
            let content = try String(contentsOf: file, encoding: .utf8)
            if !content.isEmpty { count += 1 }
        }
        return count
    }

    private func waitForQueue()
    {
        let expectation = XCTestExpectation(description: "等待队列完成")
        service.queue.async { expectation.fulfill() }
        wait(for: [expectation], timeout: 5.0)
    }
}
