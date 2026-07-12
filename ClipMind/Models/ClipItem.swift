import Foundation

struct ClipItem: Identifiable, Codable, Equatable {
    let id: UUID
    let content: ClipContent
    var contentType: ContentType
    let sourceApp: String
    let sourceAppName: String
    let timestamp: Date
    var summary: String?
    var translation: String?
    var rewrite: String?
    var todos: [TodoItem]?
    var embeddings: [Float]?
}

extension ClipItem {
    static func makeText(
        _ text: String,
        contentType: ContentType,
        sourceApp: String,
        sourceAppName: String
    ) -> ClipItem {
        ClipItem(
            id: UUID(),
            content: .text(text),
            contentType: contentType,
            sourceApp: sourceApp,
            sourceAppName: sourceAppName,
            timestamp: Date(),
            summary: nil,
            translation: nil,
            rewrite: nil,
            todos: nil,
            embeddings: nil
        )
    }

    static func makeImage(
        _ data: Data,
        contentType: ContentType,
        sourceApp: String,
        sourceAppName: String
    ) -> ClipItem {
        ClipItem(
            id: UUID(),
            content: .image(data),
            contentType: contentType,
            sourceApp: sourceApp,
            sourceAppName: sourceAppName,
            timestamp: Date(),
            summary: nil,
            translation: nil,
            rewrite: nil,
            todos: nil,
            embeddings: nil
        )
    }

    static func makeFilePath(
        _ urls: [URL],
        contentType: ContentType,
        sourceApp: String,
        sourceAppName: String
    ) -> ClipItem {
        ClipItem(
            id: UUID(),
            content: .filePath(urls),
            contentType: contentType,
            sourceApp: sourceApp,
            sourceAppName: sourceAppName,
            timestamp: Date(),
            summary: nil,
            translation: nil,
            rewrite: nil,
            todos: nil,
            embeddings: nil
        )
    }
}
