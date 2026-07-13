import AppKit
import XCTest

@testable import ClipMind

final class CaptureServiceTests: XCTestCase {
    private var pasteboard: NSPasteboard!
    private var store: EncryptedStore!
    private var dbPath: URL!
    private var service: CaptureService!

    override func setUpWithError() throws {
        pasteboard = NSPasteboard(name: .init("test-capture-\(UUID().uuidString)"))
        pasteboard.clearContents()

        dbPath = try TestDatabaseHelper.makeTempDBPath()
        store = try EncryptedStore(
            dbPath: dbPath,
            key: TestDatabaseHelper.makeTestKey()
        )

        service = CaptureService(
            pasteboard: pasteboard,
            store: store
        )
    }

    override func tearDownWithError() throws {
        service = nil
        store = nil
        if let dbPath {
            TestDatabaseHelper.cleanup(at: dbPath)
        }
        dbPath = nil
        pasteboard = nil
    }

    func testStartLoadsExistingClips() throws {
        let existing = ClipItem.makeText(
            "existing content",
            contentType: .other,
            sourceApp: "com.test",
            sourceAppName: "Test"
        )
        try store.save(existing)

        service.start()

        XCTAssertEqual(service.clips.count, 1)
        XCTAssertEqual(service.clips.first?.id, existing.id)
    }

    func testCaptureNewTextAppendsToClips() throws {
        service.start()

        pasteboard.clearContents()
        pasteboard.setString("hello world", forType: .string)
        service.watcher.handlePasteboardChange()

        XCTAssertEqual(service.clips.count, 1)
        let content = service.clips.first?.content
        guard case .text(let text) = content else {
            XCTFail("Expected text content")
            return
        }
        XCTAssertEqual(text, "hello world")
    }

    func testCaptureSavesToStore() throws {
        service.start()

        pasteboard.clearContents()
        pasteboard.setString("persist me", forType: .string)
        service.watcher.handlePasteboardChange()

        let loaded = try store.loadAll()
        XCTAssertEqual(loaded.count, 1)
        let content = loaded.first?.content
        guard case .text(let text) = content else {
            XCTFail("Expected text content")
            return
        }
        XCTAssertEqual(text, "persist me")
    }

    func testMultipleCapturesAppendInOrder() throws {
        service.start()

        pasteboard.clearContents()
        pasteboard.setString("first", forType: .string)
        service.watcher.handlePasteboardChange()

        pasteboard.clearContents()
        pasteboard.setString("second", forType: .string)
        service.watcher.handlePasteboardChange()

        XCTAssertEqual(service.clips.count, 2)

        let firstContent = service.clips[0].content
        let secondContent = service.clips[1].content
        guard case .text(let firstText) = firstContent else {
            XCTFail("Expected text content at index 0")
            return
        }
        guard case .text(let secondText) = secondContent else {
            XCTFail("Expected text content at index 1")
            return
        }
        XCTAssertEqual(firstText, "second")
        XCTAssertEqual(secondText, "first")
    }
}
