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
