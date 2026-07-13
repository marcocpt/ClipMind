import Foundation

struct BlacklistEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let bundleId: String
    let appName: String
    let addedAt: Date
    let isDefault: Bool
}
