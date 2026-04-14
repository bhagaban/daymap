import AppKit
import Combine
import Foundation
import SwiftUI

enum PlanningMode: String, CaseIterable {
    case daily
    case weekly
}

@MainActor
final class AppViewModel: ObservableObject {
    @Published private(set) var tasks: [Task] = []
    @Published var settings: AppSettings = .default
    @Published var scratchpad: Scratchpad = .empty
    @Published var selectedDate: Date = Date()
    @Published var planningMode: PlanningMode = .daily
    @Published var editorTask: Task?
    @Published var focusTask: Task?
    @Published var isSettingsPresented: Bool = false
    @Published var hoveredTaskID: UUID? = nil

    private var cancellables = Set<AnyCancellable>()
    private var focusSegmentStart: Date?
    // Running state for list-mode timer display.
    private var runningTaskID: UUID?
    private var runningSegmentStart: Date?

    func openEditor(_ task: Task) {
        editorTask = task
    }

    func openNewTaskEditor(for day: Date) {
        let dayStart = PlanningDateHelpers.startOfDay(day)
        let slot = nextDefaultSlot(on: dayStart)
        editorTask = Task(
            title: "",
            notes: nil,
            date: dayStart,
            startTime: slot.start,
            endTime: slot.end,
            isCompleted: false,
            subtasks: [],
            tags: [],
            actualTimeSpent: 0,
            isRunning: false
        )
    }

    init() {
        let payload = JSONTaskStore.load()
        // Don't resume running timers across launches.
        tasks = payload.tasks.map { t in
            var copy = t
            copy.isRunning = false
            return copy
        }
        settings = payload.settings
        scratchpad = payload.scratchpad

        $tasks
            .dropFirst()
            .debounce(for: .milliseconds(200), scheduler: RunLoop.main)
            .sink { [weak self] tasks in
                guard let self else { return }
                JSONTaskStore.save(PersistedPayload(tasks: tasks, settings: self.settings, scratchpad: self.scratchpad))
            }
            .store(in: &cancellables)

        $settings
            .dropFirst()
            .debounce(for: .milliseconds(200), scheduler: RunLoop.main)
            .sink { [weak self] settings in
                guard let self else { return }
                JSONTaskStore.save(PersistedPayload(tasks: self.tasks, settings: settings, scratchpad: self.scratchpad))
            }
            .store(in: &cancellables)

        $scratchpad
            .dropFirst()
            .debounce(for: .milliseconds(250), scheduler: RunLoop.main)
            .sink { [weak self] scratchpad in
                guard let self else { return }
                JSONTaskStore.save(PersistedPayload(tasks: self.tasks, settings: self.settings, scratchpad: scratchpad))
            }
            .store(in: &cancellables)
    }

    /// Preserves the order stored in `tasks` so drag-reorder is stable.
    func tasks(on day: Date) -> [Task] {
        tasks.filter { PlanningDateHelpers.isSameDay($0.date, day) }
    }

    func tasksSortedByTime(on day: Date) -> [Task] {
        tasks(on: day).sorted { $0.startTime < $1.startTime }
    }

    func upsert(_ task: Task) {
        if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[idx] = task
        } else {
            tasks.append(task)
        }
    }

    func delete(_ task: Task) {
        tasks.removeAll { $0.id == task.id }
        if focusTask?.id == task.id {
            focusTask = nil
        }
    }

    func deleteTasks(ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        tasks.removeAll { ids.contains($0.id) }
        if let focused = focusTask, ids.contains(focused.id) {
            focusTask = nil
        }
        if let editing = editorTask, ids.contains(editing.id) {
            editorTask = nil
        }
    }

    func toggleComplete(_ task: Task) {
        guard var next = tasks.first(where: { $0.id == task.id }) else { return }
        next.isCompleted.toggle()
        next.isRunning = false
        if next.isCompleted {
            playCompletionFeedback()
        }
        upsert(next)
    }

    func toggleSubtask(taskID: UUID, subtaskID: UUID) {
        guard var t = tasks.first(where: { $0.id == taskID }),
              let taskIndex = tasks.firstIndex(where: { $0.id == taskID }),
              let subIndex = t.subtasks.firstIndex(where: { $0.id == subtaskID })
        else { return }

        t.subtasks[subIndex].isCompleted.toggle()
        tasks[taskIndex] = t
        if focusTask?.id == taskID {
            focusTask = t
        }
    }

    func reorder(day: Date, fromOffsets: IndexSet, toOffset: Int) {
        var dayTasks = tasks(on: day)
        dayTasks.move(fromOffsets: fromOffsets, toOffset: toOffset)
        var iterator = dayTasks.makeIterator()
        tasks = tasks.map { t in
            if PlanningDateHelpers.isSameDay(t.date, day) {
                iterator.next() ?? t
            } else {
                t
            }
        }
    }

    func moveTask(_ task: Task, to newDay: Date) {
        guard var next = tasks.first(where: { $0.id == task.id }) else { return }
        let duration = next.duration
        next.date = PlanningDateHelpers.startOfDay(newDay)
        next.startTime = PlanningDateHelpers.dateByMerging(day: next.date, timeFrom: next.startTime)
        next.endTime = next.startTime.addingTimeInterval(duration)
        upsert(next)
    }

    /// Insert a task into a day at the given index and retime subsequent tasks to fit.
    /// - Important: tasks *before* `index` keep their existing times.
    func insertTask(id: UUID, into day: Date, at index: Int) {
        guard let existing = tasks.first(where: { $0.id == id }) else { return }

        let targetDay = PlanningDateHelpers.startOfDay(day)
        var dayTasks = tasksSortedByTime(on: targetDay).filter { $0.id != id }

        let clamped = max(0, min(index, dayTasks.count))
        dayTasks.insert(existing, at: clamped)

        func normalizedDuration(_ t: Task) -> TimeInterval {
            max(15 * 60, t.duration)
        }

        let workStart = PlanningDateHelpers.combine(day: targetDay, minutesFromMidnight: settings.workdayStartMinutes)

        for i in clamped..<dayTasks.count {
            var t = dayTasks[i]
            let dur = normalizedDuration(t)

            let start: Date
            if i == 0 {
                start = workStart
            } else {
                start = dayTasks[i - 1].endTime
            }

            t.date = targetDay
            t.startTime = PlanningDateHelpers.snapMinutes(start)
            t.endTime = t.startTime.addingTimeInterval(dur)

            dayTasks[i] = t
        }

        for i in clamped..<dayTasks.count {
            upsert(dayTasks[i])
        }
    }

    func updateTaskTimes(id: UUID, start: Date, end: Date) {
        guard var next = tasks.first(where: { $0.id == id }) else { return }
        let snappedStart = PlanningDateHelpers.snapMinutes(start)
        var snappedEnd = PlanningDateHelpers.snapMinutes(end)
        if snappedEnd <= snappedStart {
            snappedEnd = snappedStart.addingTimeInterval(15 * 60)
        }
        next.date = PlanningDateHelpers.startOfDay(snappedStart)
        next.startTime = snappedStart
        next.endTime = snappedEnd
        upsert(next)
    }

    func shiftTaskTimes(id: UUID, delta: TimeInterval) {
        guard var next = tasks.first(where: { $0.id == id }) else { return }
        let duration = next.duration
        let newStart = PlanningDateHelpers.snapMinutes(next.startTime.addingTimeInterval(delta))
        next.startTime = newStart
        next.endTime = newStart.addingTimeInterval(duration)
        next.date = PlanningDateHelpers.startOfDay(newStart)
        upsert(next)
    }

    func nextDefaultSlot(on day: Date) -> (start: Date, end: Date) {
        let existing = tasksSortedByTime(on: day)
        let defaultStart = PlanningDateHelpers.combine(day: day, minutesFromMidnight: settings.workdayStartMinutes)
        let now = Date()
        let duration: TimeInterval = 30 * 60
        
        // Today: prefer the *next clock hour* (3:15 → 4:00), then skip forward only if it overlaps.
        if PlanningDateHelpers.isSameDay(day, now) {
            var start = max(defaultStart, PlanningDateHelpers.nextHour(now))
            var end = start.addingTimeInterval(duration)
            
            func overlaps(_ aStart: Date, _ aEnd: Date, _ bStart: Date, _ bEnd: Date) -> Bool {
                aStart < bEnd && bStart < aEnd
            }
            
            // If the desired next-hour slot collides with existing tasks, move to the next full hour
            // after the latest overlapping task end, and repeat.
            while true {
                let collisions = existing.filter { overlaps(start, end, $0.startTime, $0.endTime) }
                guard let latestEnd = collisions.map(\.endTime).max() else { break }
                start = PlanningDateHelpers.nextHour(latestEnd)
                end = start.addingTimeInterval(duration)
            }
            
            return (start, end)
        }
        
        // Other days: place after the latest scheduled task, otherwise at workday start.
        guard let last = existing.max(by: { $0.endTime < $1.endTime }) else {
            let start = defaultStart
            return (start, start.addingTimeInterval(duration))
        }
        let start = max(last.endTime, defaultStart)
        return (start, start.addingTimeInterval(duration))
    }

    func beginFocus(_ task: Task) {
        focusTask = task
        focusSegmentStart = nil
    }
    
    /// Starts or pauses a task from the list. Ensures only one task is running at a time.
    func toggleStartFromList(_ task: Task) {
        guard let stored = tasks.first(where: { $0.id == task.id }) else { return }
        if stored.isRunning {
            pauseTask(stored)
        } else {
            startTask(stored)
        }
    }

    func focusStartTimer() {
        guard let t = focusTask else { return }
        startTask(t)
    }

    func focusPauseTimer() {
        guard let t = focusTask else { return }
        pauseTask(t)
    }

    func focusToggleTimer() {
        guard let t = focusTask else { return }
        if t.isRunning {
            focusPauseTimer()
        } else {
            focusStartTimer()
        }
    }

    func focusComplete() {
        guard let t = focusTask else { return }
        if t.isRunning {
            pauseTask(t)
        }
        guard var updated = tasks.first(where: { $0.id == t.id }),
              let idx = tasks.firstIndex(where: { $0.id == t.id })
        else {
            focusTask = nil
            return
        }
        updated.isCompleted = true
        updated.isRunning = false
        tasks[idx] = updated
        focusTask = nil
        playCompletionFeedback()
    }

    func closeFocus() {
        // Close only dismisses the focus UI. It should not stop the timer.
        focusTask = nil
    }

    func syncFocusTaskFromStore() {
        guard let id = focusTask?.id, let latest = tasks.first(where: { $0.id == id }) else { return }
        focusTask = latest
    }

    /// Elapsed focus time including the in-flight running segment (if any).
    func focusDisplayedSpent(at reference: Date) -> TimeInterval {
        guard let id = focusTask?.id else { return 0 }
        return displayedSpent(forTaskID: id, at: reference)
    }

    func displayedSpent(forTaskID id: UUID, at reference: Date) -> TimeInterval {
        guard let stored = tasks.first(where: { $0.id == id }) else { return 0 }
        var total = stored.actualTimeSpent
        if stored.isRunning, runningTaskID == id, let start = runningSegmentStart {
            total += reference.timeIntervalSince(start)
        }
        return total
    }

    func startTask(_ task: Task) {
        // Pause any currently running task (records time).
        if let runningID = runningTaskID,
           runningID != task.id,
           let running = tasks.first(where: { $0.id == runningID }),
           running.isRunning {
            pauseTask(running)
        }

        guard var t = tasks.first(where: { $0.id == task.id }),
              let idx = tasks.firstIndex(where: { $0.id == task.id })
        else { return }

        if t.isRunning { return }
        t.isRunning = true
        tasks[idx] = t

        runningTaskID = t.id
        runningSegmentStart = Date()
        focusSegmentStart = runningSegmentStart
        if focusTask?.id == t.id { focusTask = t }
        NSSound(named: NSSound.Name("Pop"))?.play()
    }

    func pauseTask(_ task: Task) {
        guard var t = tasks.first(where: { $0.id == task.id }),
              let idx = tasks.firstIndex(where: { $0.id == task.id })
        else { return }
        guard t.isRunning else { return }

        if runningTaskID == t.id, let start = runningSegmentStart {
            t.actualTimeSpent += Date().timeIntervalSince(start)
        }
        t.isRunning = false
        tasks[idx] = t

        if runningTaskID == t.id {
            runningTaskID = nil
            runningSegmentStart = nil
            focusSegmentStart = nil
        }
        if focusTask?.id == t.id { focusTask = t }
        NSSound(named: NSSound.Name("Tink"))?.play()
    }

    private func playCompletionFeedback() {
        // Prefer a crisp "done" sound; fall back to a light tick.
        let preferred: [String] = ["Glass", "Hero", "Funk", "Tink"]
        for name in preferred {
            if let sound = NSSound(named: NSSound.Name(name)) {
                sound.play()
                return
            }
        }
    }
}
