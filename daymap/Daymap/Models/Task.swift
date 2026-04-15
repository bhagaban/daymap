import Foundation

struct Task: Identifiable, Codable, Hashable, Equatable, Sendable {
    var id: UUID
    var title: String
    var notes: String?
    var date: Date
    var startTime: Date
    var endTime: Date
    var isCompleted: Bool
    var subtasks: [Subtask]
    var tags: [String]
    var actualTimeSpent: TimeInterval
    var isRunning: Bool

    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }

    // Backwards-compatible decoding: older saved payloads may not have newer fields.
    // We default missing values instead of failing the entire payload decode.
    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case notes
        case date
        case startTime
        case endTime
        case isCompleted
        case subtasks
        case tags
        case actualTimeSpent
        case isRunning
    }

    private struct AnyCodingKey: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }
        init?(intValue: Int) { return nil }
        init?(stringValue: String) { self.stringValue = stringValue }
        init(_ string: String) { self.stringValue = string }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        notes = try? c.decodeIfPresent(String.self, forKey: .notes)
        date = (try? c.decode(Date.self, forKey: .date)) ?? Date()
        startTime = (try? c.decode(Date.self, forKey: .startTime)) ?? date
        endTime = (try? c.decode(Date.self, forKey: .endTime)) ?? startTime.addingTimeInterval(30 * 60)
        isCompleted = (try? c.decode(Bool.self, forKey: .isCompleted)) ?? false

        // Subtasks had a few plausible historical spellings. Try the current key first,
        // then fall back to legacy keys if present.
        if let subs = try? c.decodeIfPresent([Subtask].self, forKey: .subtasks) {
            subtasks = subs
        } else {
            let legacy = try decoder.container(keyedBy: AnyCodingKey.self)
            subtasks =
                (try? legacy.decode([Subtask].self, forKey: AnyCodingKey("subTasks"))) ??
                (try? legacy.decode([Subtask].self, forKey: AnyCodingKey("checklist"))) ??
                []
        }

        tags = (try? c.decodeIfPresent([String].self, forKey: .tags)) ?? []
        actualTimeSpent = (try? c.decodeIfPresent(TimeInterval.self, forKey: .actualTimeSpent)) ?? 0
        isRunning = (try? c.decodeIfPresent(Bool.self, forKey: .isRunning)) ?? false
    }

    init(
        id: UUID = UUID(),
        title: String,
        notes: String? = nil,
        date: Date,
        startTime: Date,
        endTime: Date,
        isCompleted: Bool = false,
        subtasks: [Subtask] = [],
        tags: [String] = [],
        actualTimeSpent: TimeInterval = 0,
        isRunning: Bool = false
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.date = date
        self.startTime = startTime
        self.endTime = endTime
        self.isCompleted = isCompleted
        self.subtasks = subtasks
        self.tags = tags
        self.actualTimeSpent = actualTimeSpent
        self.isRunning = isRunning
    }
}
