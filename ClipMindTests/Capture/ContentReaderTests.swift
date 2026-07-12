import AppKit
import XCTest

@testable import ClipMind

final class ContentReaderTests: XCTestCase {
    private var reader: ContentReader!
    private var pasteboard: NSPasteboard!

    override func setUpWithError() throws {
        reader = ContentReader()
        pasteboard = NSPasteboard(name: .init("test-content-reader-\(UUID().uuidString)"))
        pasteboard.clearContents()
    }

    override func tearDownWithError() throws {
        reader = nil
        pasteboard = nil
    }

    // MARK: - 文本读取

    func testReadText() throws {
        pasteboard.setString("hello", forType: .string)

        let text = reader.readText(from: pasteboard)
        XCTAssertEqual(text, "hello")
    }

    func testReadTextEmpty() throws {
        let content = reader.readContent(from: pasteboard)
        XCTAssertNil(content, "空 pasteboard 应返回 nil")
    }

    // MARK: - 图片读取

    func testReadImage() throws {
        let image = TestImageFactory.makeImage(width: 100, height: 100)
        let tiffData = try XCTUnwrap(image.tiffRepresentation)
        pasteboard.setData(tiffData, forType: .tiff)

        let imageData = reader.readImage(from: pasteboard)
        XCTAssertNotNil(imageData, "应能读取图片数据")
    }

    func testReadImageNil() throws {
        let imageData = reader.readImage(from: pasteboard)
        XCTAssertNil(imageData, "无图片时应返回 nil")
    }

    // MARK: - 文件路径读取

    func testReadFilePaths() throws {
        let url = URL(fileURLWithPath: "/tmp/test-file.txt")
        pasteboard.clearContents()
        pasteboard.writeObjects([url as NSURL])

        let urls = reader.readFilePaths(from: pasteboard)
        XCTAssertEqual(urls?.count, 1)
        XCTAssertEqual(urls?.first?.path, "/tmp/test-file.txt")
    }

    func testReadFilePathsNil() throws {
        let urls = reader.readFilePaths(from: pasteboard)
        XCTAssertNil(urls, "无文件 URL 时应返回 nil")
    }

    // MARK: - 优先级

    func testReadTextPriority() throws {
        let url = URL(fileURLWithPath: "/tmp/test-file.txt")
        pasteboard.clearContents()
        pasteboard.setString("hello text", forType: .string)
        pasteboard.writeObjects([url as NSURL])

        let content = reader.readContent(from: pasteboard)
        guard case .text(let value) = content else {
            XCTFail("应优先返回文本，实际: \(String(describing: content))")
            return
        }
        XCTAssertEqual(value, "hello text")
    }

    // MARK: - 缩略图尺寸

    func testImageThumbnailSize() throws {
        let image = TestImageFactory.makeImage(width: 500, height: 500)
        let tiffData = try XCTUnwrap(image.tiffRepresentation)
        pasteboard.setData(tiffData, forType: .tiff)

        let thumbnailData = try XCTUnwrap(reader.readImage(from: pasteboard))
        let thumbnail = try XCTUnwrap(NSImage(data: thumbnailData))

        XCTAssertLessThanOrEqual(thumbnail.size.width, 200.0, "缩略图宽度不应超过 200")
        XCTAssertLessThanOrEqual(thumbnail.size.height, 200.0, "缩略图高度不应超过 200")
    }

    // MARK: - readContent 综合判断

    func testReadContentText() throws {
        pasteboard.setString("hello", forType: .string)

        let content = reader.readContent(from: pasteboard)
        guard case .text(let value) = content else {
            XCTFail("应返回 .text 类型")
            return
        }
        XCTAssertEqual(value, "hello")
    }

    func testReadContentImage() throws {
        let image = TestImageFactory.makeImage(width: 100, height: 100)
        let tiffData = try XCTUnwrap(image.tiffRepresentation)
        pasteboard.setData(tiffData, forType: .tiff)

        let content = reader.readContent(from: pasteboard)
        guard case .image = content else {
            XCTFail("应返回 .image 类型")
            return
        }
    }

    func testReadContentFilePath() throws {
        let url = URL(fileURLWithPath: "/tmp/test-file.txt")
        pasteboard.clearContents()
        pasteboard.writeObjects([url as NSURL])

        let content = reader.readContent(from: pasteboard)
        guard case .filePath(let urls) = content else {
            XCTFail("应返回 .filePath 类型")
            return
        }
        XCTAssertEqual(urls.count, 1)
    }
}

// MARK: - 测试图片工厂

enum TestImageFactory {
    static func makeImage(width: Int, height: Int) -> NSImage {
        guard let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            fatalError("无法创建测试用 NSBitmapImageRep")
        }
        let image = NSImage(size: NSSize(width: width, height: height))
        image.addRepresentation(bitmapRep)
        return image
    }
}
