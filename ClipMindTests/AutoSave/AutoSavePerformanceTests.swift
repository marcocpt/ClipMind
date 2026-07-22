import AppKit
import XCTest

@testable import ClipMind

/// 性能测试（D21 记录实际耗时并断言 P95）。
final class AutoSavePerformanceTests: XCTestCase
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

    // MARK: - D21：性能测试记录实际耗时并断言 P95

    func testPerformanceP95Latency() throws
    {
        let iterations = 20
        var latencies: [TimeInterval] = []

        for _ in 0..<iterations
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

            let start = Date()
            service.handle(event: event)
            waitForQueue()
            latencies.append(Date().timeIntervalSince(start))
        }

        latencies.sort()
        let p95Index = Int(Double(iterations) * 0.95)
        let p95 = latencies[min(p95Index, iterations - 1)]

        XCTContext.runActivity(named: "D21 性能测试") { activity in
            let attachment = XCTAttachment(string: "P95 延迟 = \(p95)s，共 \(iterations) 次迭代")
            attachment.name = "performance-metrics"
            attachment.lifetime = .keepAlways
            activity.add(attachment)
        }

        XCTAssertLessThan(p95, 1.0, "D21：P95 延迟应小于 1s，实际：\(p95)s")
    }

    private func waitForQueue()
    {
        let expectation = XCTestExpectation(description: "等待队列完成")
        service.queue.async { expectation.fulfill() }
        wait(for: [expectation], timeout: 5.0)
    }
}
