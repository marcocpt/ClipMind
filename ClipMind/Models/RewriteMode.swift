import Foundation

enum RewriteMode: String, Codable, CaseIterable {
    case adjustTone = "adjust_tone"
    case condense
    case expand
}
