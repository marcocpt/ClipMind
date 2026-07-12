import Foundation

struct TodoItem: Identifiable, Codable, Equatable {
    let id: UUID
    var task: String
    var assignee: String?
    var dueDate: String?
}
