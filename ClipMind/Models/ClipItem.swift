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
    var isSample: Bool = false
}

// MARK: - 自定义 Codable 向后兼容

extension ClipItem {
    enum CodingKeys: String, CodingKey {
        case id
        case content
        case contentType
        case sourceApp
        case sourceAppName
        case timestamp
        case summary
        case translation
        case rewrite
        case todos
        case embeddings
        case isSample
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        content = try container.decode(ClipContent.self, forKey: .content)
        contentType = try container.decode(ContentType.self, forKey: .contentType)
        sourceApp = try container.decode(String.self, forKey: .sourceApp)
        sourceAppName = try container.decode(String.self, forKey: .sourceAppName)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
        translation = try container.decodeIfPresent(String.self, forKey: .translation)
        rewrite = try container.decodeIfPresent(String.self, forKey: .rewrite)
        todos = try container.decodeIfPresent([TodoItem].self, forKey: .todos)
        embeddings = try container.decodeIfPresent([Float].self, forKey: .embeddings)
        // 向后兼容：旧数据无 isSample 字段时默认 false
        isSample = try container.decodeIfPresent(Bool.self, forKey: .isSample) ?? false
    }
}

// MARK: - 工厂方法

extension ClipItem {
    static func makeText(
        _ text: String,
        contentType: ContentType,
        sourceApp: String,
        sourceAppName: String,
        isSample: Bool = false
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
            embeddings: nil,
            isSample: isSample
        )
    }

    static func makeImage(
        _ data: Data,
        contentType: ContentType,
        sourceApp: String,
        sourceAppName: String,
        isSample: Bool = false
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
            embeddings: nil,
            isSample: isSample
        )
    }

    static func makeFilePath(
        _ urls: [URL],
        contentType: ContentType,
        sourceApp: String,
        sourceAppName: String,
        isSample: Bool = false
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
            embeddings: nil,
            isSample: isSample
        )
    }
}
