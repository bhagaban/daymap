import Foundation

struct ScratchItem: Identifiable, Codable, Hashable, Equatable, Sendable {
    var id: UUID = UUID()
    var title: String
    var isCompleted: Bool = false
    var createdAt: Date = Date()

    init(id: UUID = UUID(), title: String, isCompleted: Bool = false, createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.createdAt = createdAt
    }
}

struct Scratchpad: Codable, Hashable, Equatable, Sendable {
    var notes: String = ""
    var items: [ScratchItem] = []

    static let empty = Scratchpad()
}

