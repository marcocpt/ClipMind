import Foundation

enum ClipContent: Codable, Equatable {
    case text(String)
    case image(Data)
    case filePath([URL])

    private enum CodingKeys: String, CodingKey {
        case type
        case value
    }

    private enum Kind: String, Codable {
        case text
        case image
        case filePath
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .type)
        switch kind {
        case .text:
            let value = try container.decode(String.self, forKey: .value)
            self = .text(value)
        case .image:
            let value = try container.decode(Data.self, forKey: .value)
            self = .image(value)
        case .filePath:
            let value = try container.decode([URL].self, forKey: .value)
            self = .filePath(value)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let value):
            try container.encode(Kind.text, forKey: .type)
            try container.encode(value, forKey: .value)
        case .image(let value):
            try container.encode(Kind.image, forKey: .type)
            try container.encode(value, forKey: .value)
        case .filePath(let value):
            try container.encode(Kind.filePath, forKey: .type)
            try container.encode(value, forKey: .value)
        }
    }
}
