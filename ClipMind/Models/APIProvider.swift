import Foundation

enum APIProvider: String, Codable, CaseIterable {
    case openai
    case zhipu
    case qianwen
    case deepseek
}
