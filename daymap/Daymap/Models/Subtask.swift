import Foundation

struct Subtask: Identifiable, Codable, Hashable, Equatable, Sendable {
    var id: UUID
    var title: String
    var isCompleted: Bool

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case isCompleted
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        isCompleted = (try? c.decodeIfPresent(Bool.self, forKey: .isCompleted)) ?? false
    }

    init(id: UUID = UUID(), title: String, isCompleted: Bool = false) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
    }
}
