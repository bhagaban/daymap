import SwiftUI
import UniformTypeIdentifiers

struct WeeklyBoardView: View {
    @EnvironmentObject private var model: AppViewModel

    private var days: [Date] {
        PlanningDateHelpers.daysInWeekMondayFirst(containing: model.selectedDate)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 16) {
                    ForEach(Array(days.enumerated()), id: \.element) { idx, day in
                        WeekColumn(day: day)
                            .frame(width: 260)
                            .opacity(isWeekend(day) ? 0.90 : 1.0)
                            .id(dayID(day))

                        if idx == 4 {
                            // Subtle separator after Friday so weekends feel "off to the right".
                            Rectangle()
                                .fill(Color.white.opacity(0.06))
                                .frame(width: 1)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 2)
                        }
                    }
                }
                .padding(16)
            }
            .onAppear {
                scrollToMonday(proxy)
            }
            .onChange(of: model.selectedDate) { _, _ in
                scrollToMonday(proxy)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.35))
    }

    private func dayID(_ day: Date) -> String {
        let d = PlanningDateHelpers.startOfDay(day)
        return d.formatted(.dateTime.year().month().day())
    }

    private func scrollToMonday(_ proxy: ScrollViewProxy) {
        guard let monday = days.first else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.easeInOut(duration: 0.25)) {
                proxy.scrollTo(dayID(monday), anchor: .leading)
            }
        }
    }

    private func isWeekend(_ day: Date) -> Bool {
        PlanningDateHelpers.calendar.isDateInWeekend(day)
    }
}

private struct WeekColumn: View {
    @EnvironmentObject private var model: AppViewModel
    let day: Date
    @State private var targetedIndex: Int? = nil
    @State private var columnTargeted: Bool = false

    var body: some View {
        let tasks = model.tasksSortedByTime(on: day)
        let isToday = PlanningDateHelpers.isSameDay(day, Date())
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(day.formatted(.dateTime.weekday(.wide)))
                    .font(.headline.weight(isToday ? .semibold : .regular))
                Text(day.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button {
                model.selectedDate = PlanningDateHelpers.startOfDay(day)
                model.planningMode = .daily
            } label: {
                Label("Open day", systemImage: "arrow.right.circle")
                    .font(.caption)
            }
            .buttonStyle(.borderless)

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    DropSlot(isTargeted: targetedIndex == 0 || (tasks.isEmpty && columnTargeted))
                    .onDrop(of: [.plainText], isTargeted: nil) { providers, _ in
                        handleDrop(providers: providers, insertIndex: 0)
                    }

                    ForEach(Array(tasks.enumerated()), id: \.element.id) { idx, task in
                        TaskCardView(
                            task: task,
                            compact: true,
                            onEdit: { model.openEditor(task) },
                            onToggleComplete: { model.toggleComplete(task) },
                            onToggleStart: { model.toggleStartFromList(task) },
                            onOpenFocus: { model.beginFocus(task) }
                        )
                        .padding(.horizontal, 2)
                        .onDrag {
                            NSItemProvider(object: task.id.uuidString as NSString)
                        }
                        .overlay(alignment: .bottom) {
                            DropSlot(isTargeted: targetedIndex == idx + 1)
                                .padding(.top, 6)
                                .onDrop(of: [.plainText], isTargeted: nil) { providers, _ in
                                    handleDrop(providers: providers, insertIndex: idx + 1)
                                }
                        }
                    }
                    
                    if tasks.isEmpty {
                        Color.clear
                            .frame(maxWidth: .infinity, minHeight: 160)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(
                                        Color.accentColor.opacity(columnTargeted ? 0.28 : 0.0),
                                        style: StrokeStyle(lineWidth: 1, dash: [7, 7])
                                    )
                                    .animation(.easeInOut(duration: 0.12), value: columnTargeted)
                            )
                            .padding(.top, 6)
                    }
                }
                .padding(.vertical, 4)
                .animation(.easeInOut(duration: 0.12), value: targetedIndex)
            }
            .frame(minHeight: 220)
            .onDrop(of: [.plainText], isTargeted: $columnTargeted) { providers, _ in
                // Dropping on blank area inserts at end.
                handleDrop(providers: providers, insertIndex: tasks.count)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isToday ? Color.accentColor.opacity(0.07) : Color(nsColor: .controlBackgroundColor).opacity(0.55))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(isToday ? Color.accentColor.opacity(0.22) : Color.white.opacity(0.05), lineWidth: 1)
        }
        .overlay(alignment: .topTrailing) {
            if isToday {
                Text("Today")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.accentColor.opacity(0.85))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill(Color.accentColor.opacity(0.12))
                    )
                    .padding(10)
            }
        }
    }

    private func handleDrop(providers: [NSItemProvider], insertIndex: Int) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadObject(ofClass: NSString.self) { reading, _ in
            guard let str = reading as? String, let uuid = UUID(uuidString: str) else { return }
            DispatchQueue.main.async {
                model.insertTask(id: uuid, into: day, at: insertIndex)
                targetedIndex = nil
            }
        }
        return true
    }
}

private struct DropSlot: View {
    let isTargeted: Bool

    var body: some View {
        Rectangle()
            .fill(isTargeted ? Color.accentColor.opacity(0.85) : Color.clear)
            .frame(height: isTargeted ? 3 : 2)
            .overlay(
                Rectangle()
                    .fill(Color.accentColor.opacity(isTargeted ? 0.25 : 0.0))
                    .frame(height: 16)
                    .blur(radius: 8)
                    .opacity(isTargeted ? 1 : 0)
            )
            .padding(.horizontal, 4)
            .animation(.easeInOut(duration: 0.12), value: isTargeted)
    }
}
