import AppKit
import CryptoKit
import Foundation
import XCTest

@testable import ClipMind

final class NewClipTagIntegrationTests: XCTestCase
{
    private var pasteboard: NSPasteboard!
    private var watcher: PasteboardWatcher!
    private var store: EncryptedStore!
    private var service: ClipCaptureService!
    private var tempDir: URL!
    private var dbPath: URL!

    override func setUpWithError() throws
    {
        pasteboard = NSPasteboard(name: .init("test-tag-\(UUID().uuidString)"))
        pasteboard.clearContents()

        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        dbPath = tempDir.appendingPathComponent("test_tag_integration.db")
        let key = SymmetricKey(data: Data(repeating: 0xAB, count: 32))
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

    override func tearDownWithError() throws
    {
        service?.stop()
        watcher?.stopWatching()
        if let tempDir = tempDir
        {
            try? FileManager.default.removeItem(at: tempDir)
        }
    }

    // MARK: - DOM-011: 文本条目保存后携带自身系统标签

    func testTextClipSavedWithOwnSystemTag() throws
    {
        pasteboard.clearContents()
        pasteboard.setString("print('hello')", forType: .string)
        watcher.handlePasteboardChange()

        let items = try store.loadAll()
        XCTAssertEqual(items.count, 1)

        let item = items[0]
        XCTAssertEqual(
            item.tagState,
            .newItem(contentType: item.contentType),
            "新条目应携带与 contentType 匹配的系统标签"
        )
        XCTAssertEqual(item.tagState.systemTagDisposition, .associated)
        XCTAssertTrue(item.tagState.orderedTagIDs.contains(.system(item.contentType)))
    }

    // MARK: - 图片条目保存后携带自身系统标签

    func testImageClipSavedWithOwnSystemTag() throws
    {
        let bitmapRep = try XCTUnwrap(NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 10,
            pixelsHigh: 10,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ))
        let image = NSImage(size: NSSize(width: 10, height: 10))
        image.addRepresentation(bitmapRep)
        let tiffData = try XCTUnwrap(image.tiffRepresentation)

        pasteboard.clearContents()
        pasteboard.setData(tiffData, forType: .tiff)
        watcher.handlePasteboardChange()

        let items = try store.loadAll()
        XCTAssertEqual(items.count, 1)

        let item = items[0]
        XCTAssertEqual(item.tagState.systemTagDisposition, .associated)
        XCTAssertTrue(item.tagState.orderedTagIDs.contains(.system(item.contentType)))
    }

    // MARK: - 文件路径条目保存后携带自身系统标签

    func testFilePathClipSavedWithOwnSystemTag() throws
    {
        let url = URL(fileURLWithPath: "/tmp/test_file.txt")
        pasteboard.clearContents()
        pasteboard.writeObjects([url as NSURL])
        watcher.handlePasteboardChange()

        let items = try store.loadAll()
        XCTAssertEqual(items.count, 1)

        let item = items[0]
        XCTAssertEqual(item.tagState.systemTagDisposition, .associated)
        XCTAssertTrue(item.tagState.orderedTagIDs.contains(.system(item.contentType)))
    }

    // MARK: - 保存失败时不通知 UI

    func testSaveFailureDoesNotNotify() throws
    {
        // 先保存一条数据验证 store 可用
        pasteboard.clearContents()
        pasteboard.setString("first", forType: .string)
        watcher.handlePasteboardChange()

        let initialItems = try store.loadAll()
        XCTAssertEqual(initialItems.count, 1)

        // 将数据库目录设为只读，使后续保存失败（包括 WAL 文件）
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o555],
            ofItemAtPath: tempDir.path
        )

        var notificationReceived = false
        let observer = NotificationCenter.default.addObserver(
            forName: ClipCaptureService.clipDidUpdateNotification,
            object: nil,
            queue: nil
        ) { _ in
            notificationReceived = true
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        var onClipStoredCalled = false
        service.onClipStored = { _ in
            onClipStoredCalled = true
        }

        pasteboard.clearContents()
        pasteboard.setString("second", forType: .string)
        watcher.handlePasteboardChange()

        // 等待可能的异步通知
        let expectation = XCTestExpectation(description: "等待通知")
        expectation.isInverted = true
        wait(for: [expectation], timeout: 1)

        XCTAssertFalse(notificationReceived, "保存失败不应发送通知")
        XCTAssertFalse(onClipStoredCalled, "保存失败不应调用 onClipStored")

        // 恢复权限并验证数据库无半完成条目
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: tempDir.path
        )
        let finalItems = try store.loadAll()
        XCTAssertEqual(finalItems.count, 1, "保存失败不应产生半完成条目")
    }

    // MARK: - onClipStored 收到带系统标签的条目

    func testOnClipStoredReceivesItemWithSystemTag() throws
    {
        var receivedItem: ClipItem?
        service.onClipStored = { item in
            receivedItem = item
        }

        pasteboard.clearContents()
        pasteboard.setString("test content", forType: .string)
        watcher.handlePasteboardChange()

        let item = try XCTUnwrap(receivedItem)
        XCTAssertEqual(
            item.tagState.systemTagDisposition,
            .associated,
            "onClipStored 收到的条目应携带 associated 系统标签"
        )
        XCTAssertTrue(item.tagState.orderedTagIDs.contains(.system(item.contentType)))
    }
}
