import Foundation

enum ContentType: String, Codable, CaseIterable {
    case code
    case link
    case error
    case article
    case todo
    case meeting
    case translation
    case requirement
    case apiDoc = "api_doc"
    case englishDoc = "english_doc"
    case other
}
