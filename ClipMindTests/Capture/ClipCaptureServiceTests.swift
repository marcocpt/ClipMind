import AppKit
import CryptoKit
import XCTest

@testable import ClipMind

final class ClipCaptureServiceTests: XCTestCase {
    private var pasteboard: NSPasteboard!
    private var watcher: PasteboardWatcher!
    private var store: EncryptedStore!
    private var service: ClipCaptureService!
    private var tempDir: URL!

    override func setUpWithError() throws {
        pasteboard = NSPasteboard(name: .init("test-capture-\(UUID().uuidString)"))
        pasteboard.clearContents()

        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let dbPath = tempDir.appendingPathComponent("test_capture.db")
        // 使用固定密钥避免依赖设备 UUID
        let key = SymmetricKey(size: .bits256)
        store = try EncryptedStore(dbPath: dbPath, key: key)

        watcher = PasteboardWatcher(pasteboard: pasteboard)
        let embeddingService = LocalEmbeddingService()
        let classifier = ClassificationService(embeddingService: embeddingService)
        service = ClipCaptureService(
            watcher: watcher,
            store: store,
            classifier: classifier
        )
    }

    override func tearDownWithError() throws {
        service?.stop()
        watcher?.stopWatching()
        if let tempDir = tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
    }

    // MARK: - 剪贴板变化入库

    func testClipboardTextChangeSavesClipItem() throws {
        // 模拟剪贴板变化
        pasteboard.clearContents()
        pasteboard.setString("hello world", forType: .string)
        watcher.handlePasteboardChange()

        // 验证 EncryptedStore 新增一条记录
        let items = try store.loadAll()
        XCTAssertEqual(items.count, 1, "剪贴板变化后应入库一条记录")

        let item = try XCTUnwrap(items.first)
        guard case .text(let text) = item.content else {
            XCTFail("应为 .text 类型，实际为 \(item.content)")
            return
        }
        XCTAssertEqual(text, "hello world")
    }

    func testDifferentContentSavesMultipleItems() throws {
        pasteboard.clearContents()
        pasteboard.setString("first content", forType: .string)
        watcher.handlePasteboardChange()

        pasteboard.clearContents()
        pasteboard.setString("second content", forType: .string)
        watcher.handlePasteboardChange()

        let items = try store.loadAll()
        XCTAssertEqual(items.count, 2, "两次不同内容应入库两条记录")
    }

    // MARK: - 入库通知

    func testClipUpdateNotificationPosted() throws {
        let expectation = XCTestExpectation(description: "入库后应发送 clipDidUpdate 通知")

        let observer = NotificationCenter.default.addObserver(
            forName: ClipCaptureService.clipDidUpdateNotification,
            object: nil,
            queue: .main
        ) { _ in
            expectation.fulfill()
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        pasteboard.clearContents()
        pasteboard.setString("notification test", forType: .string)
        watcher.handlePasteboardChange()

        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - 启动与停止

    func testStartActivatesWatcher() throws {
        service.start()
        XCTAssertNotNil(watcher.timer, "start 后 watcher.timer 应不为 nil")
    }

    func testStopDeactivatesWatcher() throws {
        service.start()
        service.stop()
        XCTAssertNil(watcher.timer, "stop 后 watcher.timer 应为 nil")
    }
}
