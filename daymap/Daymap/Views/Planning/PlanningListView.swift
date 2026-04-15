import SwiftUI

struct PlanningListView: View {
    @EnvironmentObject private var model: AppViewModel
    
    private let contentMaxWidth: CGFloat = 420
    @State private var addHovered = false
    @State private var targetedIndex: Int? = nil
    @State private var selectedTaskIDs: Set<UUID> = []

    var body: some View {
        let day = PlanningDateHelpers.startOfDay(model.selectedDate)
        let sorted = model.tasksSortedByTime(on: day)
        HStack {
            // Align content toward the split divider (right edge).
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 16) {
                header

                addTaskButton

                if sorted.isEmpty {
                    empty
                } else {
                    List {
                        ForEach(Array(sorted.enumerated()), id: \.element.id) { idx, task in
                            taskRow(task: task, index: idx, day: day, endIndex: sorted.count)
                        }

                        // Allow dropping to the end of the day list.
                        Color.clear
                            .frame(height: 24)
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .onDrop(of: [.text], isTargeted: nil) { providers in
                                handleDrop(providers: providers, into: day, at: sorted.count)
                            }
                    }
                    .listStyle(.plain)
                    .selectionDisabled(true)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 360)
                    .animation(.spring(response: 0.32, dampingFraction: 0.86), value: sorted.map(\.id))
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: contentMaxWidth)
            .padding(.leading, 18)
            .padding(.trailing, 10)
            .padding(.vertical, 20)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(headerTitle)
                .font(.largeTitle.weight(.bold))
            Text("Fill in your work for the day.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Text("Work: \(plannedDurationString)")
                    .font(.caption.monospacedDigit())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.secondary.opacity(0.12)))

                if selectedTaskIDs.count > 1 {
                    Button(role: .destructive) {
                        model.deleteTasks(ids: selectedTaskIDs)
                        selectedTaskIDs.removeAll()
                    } label: {
                        Text("Delete \(selectedTaskIDs.count)")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(.red)
                }

                Spacer()
            }
        }
    }

    private var headerTitle: String {
        if PlanningDateHelpers.isSameDay(model.selectedDate, Date()) {
            return "Today"
        }
        return model.selectedDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    private var plannedDurationString: String {
        let secs = model.tasks(on: model.selectedDate)
            .filter { !$0.isCompleted }
            .reduce(0.0) { $0 + max(0, $1.duration) }
        let m = Int(secs / 60)
        let h = m / 60
        let mm = m % 60
        return "\(h):\(String(format: "%02d", mm))"
    }

    private var empty: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.tertiary)
            Text("No tasks planned")
                .font(.headline.weight(.semibold))
            Text("Start by adding a task, or press N.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 220)
    }

    private var addTaskButton: some View {
        Button {
            model.openNewTaskEditor(for: model.selectedDate)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text("Add task")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(DS.Surface.card.opacity(addHovered ? 0.98 : 0.92))
                    .shadow(color: .black.opacity(addHovered ? 0.14 : 0.10), radius: addHovered ? 14 : 12, x: 0, y: addHovered ? 8 : 6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(addHovered ? DS.Surface.hairlineStrong : DS.Surface.hairline, lineWidth: 1)
            )
            .scaleEffect(addHovered ? 1.01 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.86), value: addHovered)
        }
        .buttonStyle(.plain)
        .onHover { addHovered = $0 }
        .help("Create a new task")
    }

    private func handleDrop(providers: [NSItemProvider], into day: Date, at index: Int) -> Bool {
        targetedIndex = nil
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: "public.text", options: nil) { item, _ in
            let text: String?
            if let s = item as? String {
                text = s
            } else if let data = item as? Data {
                text = String(data: data, encoding: .utf8)
            } else if let ns = item as? NSString {
                text = ns as String
            } else {
                text = nil
            }
            guard let raw = text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  let id = UUID(uuidString: raw)
            else { return }
            DispatchQueue.main.async {
                model.insertTask(id: id, into: day, at: index)
            }
        }
        return true
    }

    private func handleTap(taskID: UUID, task: Task) {
        // Cmd-click toggles selection. Regular click opens edit (and clears selection).
        let mods = NSEvent.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if mods.contains(.command) {
            if selectedTaskIDs.contains(taskID) {
                selectedTaskIDs.remove(taskID)
            } else {
                selectedTaskIDs.insert(taskID)
            }
        } else {
            selectedTaskIDs.removeAll()
            model.openEditor(task)
        }
    }

    @ViewBuilder
    private func taskRow(task: Task, index idx: Int, day: Date, endIndex: Int) -> some View {
        let isSelected = selectedTaskIDs.contains(task.id)
        let isTargeted = targetedIndex == idx
        let targetBinding = Binding(
            get: { targetedIndex == idx },
            set: { hovering in
                targetedIndex = hovering ? idx : (targetedIndex == idx ? nil : targetedIndex)
            }
        )

        TaskCardView(
            task: task,
            tapToEdit: false,
            onEdit: { model.openEditor(task) },
            onToggleComplete: { model.toggleComplete(task) },
            onToggleStart: { model.toggleStartFromList(task) },
            onOpenFocus: { model.beginFocus(task) }
        )
        .transition(.opacity.combined(with: .move(edge: .top)))
        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isTargeted ? Color.accentColor.opacity(0.35) : Color.clear, lineWidth: 1.5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.accentColor.opacity(isSelected ? 0.10 : 0.0))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isSelected ? Color.accentColor.opacity(0.35) : Color.clear, lineWidth: 1.4)
        )
        .highPriorityGesture(
            TapGesture().onEnded {
                handleTap(taskID: task.id, task: task)
            }
        )
        .onDrag { NSItemProvider(object: task.id.uuidString as NSString) }
        .onDrop(of: [.text], isTargeted: targetBinding) { providers in
            handleDrop(providers: providers, into: day, at: idx)
        }
        .contextMenu {
            Button(task.isRunning ? "Pause" : "Start") { model.toggleStartFromList(task) }
            Button("Edit") { model.openEditor(task) }
            Divider()
            Button("Delete", role: .destructive) { model.delete(task) }
        }
    }
}
