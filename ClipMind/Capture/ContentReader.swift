import AppKit
import Foundation

/// 从 NSPasteboard 读取内容，返回 ClipContent。
///
/// 支持 string / fileURL / tiff 三种类型，按文本 > 图片 > 文件路径的优先级返回。
/// 图片读取后压缩为缩略图（最大尺寸 200x200，JPEG 压缩质量 0.8）。
final class ContentReader {
    /// 缩略图最大尺寸
    private let thumbnailMaxSize: CGSize

    /// JPEG 压缩质量（0.0 ~ 1.0）
    private let jpegCompressionQuality: CGFloat

    /// 默认配置：200x200 缩略图，JPEG 质量 0.8
    init(thumbnailMaxSize: CGSize = CGSize(width: 200, height: 200),
         jpegCompressionQuality: CGFloat = 0.8) {
        self.thumbnailMaxSize = thumbnailMaxSize
        self.jpegCompressionQuality = jpegCompressionQuality
    }

    /// 从 NSPasteboard 读取内容，按文本 > 图片 > 文件路径优先级返回
    func readContent(from pasteboard: NSPasteboard) -> ClipContent? {
        if let text = readText(from: pasteboard), !text.isEmpty {
            return .text(text)
        }
        if let imageData = readImage(from: pasteboard) {
            return .image(imageData)
        }
        if let urls = readFilePaths(from: pasteboard), !urls.isEmpty {
            return .filePath(urls)
        }
        return nil
    }

    /// 读取文本类型
    func readText(from pasteboard: NSPasteboard) -> String? {
        pasteboard.string(forType: .string)
    }

    /// 读取图片类型，返回缩略图 JPEG Data
    func readImage(from pasteboard: NSPasteboard) -> Data? {
        guard let tiffData = pasteboard.data(forType: .tiff),
              let image = NSImage(data: tiffData) else {
            return nil
        }
        return makeThumbnail(from: image)
    }

    /// 读取所有 .fileURL 类型的 URL
    func readFilePaths(from pasteboard: NSPasteboard) -> [URL]? {
        guard let urls = pasteboard.readObjects(forClasses: [NSURL.self],
                                                options: nil) as? [URL],
              !urls.isEmpty else {
            return nil
        }
        return urls
    }

    // MARK: - 缩略图生成

    /// 将 NSImage 缩放到 thumbnailMaxSize 以内（保持宽高比，不放大），返回 JPEG Data
    private func makeThumbnail(from image: NSImage) -> Data? {
        let originalSize = image.size
        guard originalSize.width > 0, originalSize.height > 0 else {
            return nil
        }

        let scale = min(
            thumbnailMaxSize.width / originalSize.width,
            thumbnailMaxSize.height / originalSize.height,
            1.0
        )
        let newWidth = originalSize.width * scale
        let newHeight = originalSize.height * scale
        let newSize = CGSize(width: newWidth, height: newHeight)

        guard let bitmapRep = renderImage(image, to: newSize) else {
            return nil
        }
        return bitmapRep.representation(
            using: .jpeg,
            properties: [.compressionFactor: jpegCompressionQuality]
        )
    }

    /// 将 image 绘制到指定尺寸的 bitmap 上
    private func renderImage(_ image: NSImage, to size: CGSize) -> NSBitmapImageRep? {
        guard let tiffData = image.tiffRepresentation,
              let sourceRep = NSBitmapImageRep(data: tiffData) else {
            return nil
        }

        guard let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width.rounded()),
            pixelsHigh: Int(size.height.rounded()),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return nil
        }
        bitmapRep.size = size

        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }

        guard let context = NSGraphicsContext(bitmapImageRep: bitmapRep) else {
            return nil
        }
        NSGraphicsContext.current = context

        sourceRep.draw(
            in: NSRect(origin: .zero, size: size),
            from: NSRect(origin: .zero, size: sourceRep.size),
            operation: .copy,
            fraction: 1.0,
            respectFlipped: true,
            hints: nil
        )

        return bitmapRep
    }
}
