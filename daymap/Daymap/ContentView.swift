import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppViewModel
    @State private var isDatePopoverPresented = false
    @State private var isDateHovered = false
    @State private var isDatePressed = false
    @State private var isScratchpadPresented = false

    private var editorPresented: Binding<Bool> {
        Binding(
            get: { model.editorTask != nil },
            set: { presented in
                if !presented {
                    model.editorTask = nil
                }
            }
        )
    }

    var body: some View {
        ZStack {
            NavigationStack {
                Group {
                    if model.planningMode == .daily {
                        ZStack(alignment: .bottomTrailing) {
                            HSplitView {
                                PlanningListView()
                                    .frame(minWidth: 300, idealWidth: 380, maxWidth: 560)
                                DailyTimelineView()
                                    .frame(minWidth: 420)
                            }

                            Button {
                                isScratchpadPresented = true
                            } label: {
                                Image(systemName: "note.text")
                                    .symbolRenderingMode(.monochrome)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.primary)
                                    .padding(12)
                                    .background(
                                        Circle()
                                            .fill(DS.Surface.card.opacity(0.92))
                                    )
                                    .overlay(
                                        Circle()
                                            .strokeBorder(DS.Surface.hairlineStrong, lineWidth: 1)
                                    )
                                    .shadow(color: .black.opacity(0.18), radius: 18, x: 0, y: 10)
                            }
                            .buttonStyle(.plain)
                            .help("Scratchpad")
                            .padding(.trailing, 18)
                            .padding(.bottom, 18)
                        }
                    } else {
                        WeeklyBoardView()
                    }
                }
                .navigationTitle("Daymap")
                .toolbar {
                    ToolbarItemGroup(placement: .navigation) {
                        Button {
                            isDatePopoverPresented.toggle()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 12, weight: .semibold))
                                    .symbolRenderingMode(.monochrome)
                                    .foregroundStyle(.secondary)
                                Text(datePillTitle(for: model.selectedDate))
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(.primary)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10, weight: .semibold))
                                    .symbolRenderingMode(.monochrome)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(DS.Surface.card.opacity(isDateHovered ? 0.98 : 0.92))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(isDateHovered ? DS.Surface.hairlineStrong : DS.Surface.hairline, lineWidth: 1)
                            )
                            .scaleEffect(isDatePressed ? 0.985 : (isDateHovered ? 1.01 : 1.0))
                            .animation(.spring(response: 0.26, dampingFraction: 0.86), value: isDateHovered)
                            .animation(.spring(response: 0.20, dampingFraction: 0.90), value: isDatePressed)
                        }
                        .buttonStyle(.plain)
                        .help("Pick day")
                        .keyboardShortcut("t", modifiers: [.command])
                        .onHover { isDateHovered = $0 }
                        .pressEvents { down in
                            isDatePressed = down
                        }
                        .popover(isPresented: $isDatePopoverPresented, arrowEdge: .bottom) {
                            DatePickerPopover(
                                selectedDate: $model.selectedDate,
                                onClose: { isDatePopoverPresented = false }
                            )
                            .frame(width: 310)
                        }
                    }

                    ToolbarItemGroup(placement: .primaryAction) {
                        Picker("Board", selection: $model.planningMode) {
                            Text("Daily").tag(PlanningMode.daily)
                            Text("Weekly").tag(PlanningMode.weekly)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 200)

                        Button {
                            model.isSettingsPresented = true
                        } label: {
                            Image(systemName: "gearshape")
                        }
                        .help("Settings")
                    }
                }
            }

            if let task = model.focusTask {
                FocusModeView(taskID: task.id)
                    .environmentObject(model)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity.combined(with: .scale(0.995)))
                    .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: model.focusTask?.id)
        .sheet(isPresented: $model.isSettingsPresented) {
            SettingsView()
                .environmentObject(model)
        }
        .sheet(isPresented: $isScratchpadPresented) {
            ScratchpadView()
                .environmentObject(model)
        }
        .sheet(isPresented: editorPresented) {
            Group {
                if let task = model.editorTask {
                    TaskEditorView(
                        task: task,
                        isNew: !model.tasks.contains(where: { $0.id == task.id })
                    )
                    .environmentObject(model)
                }
            }
        }
    }

    private func datePillTitle(for date: Date) -> String {
        if PlanningDateHelpers.isSameDay(date, Date()) {
            return "Today"
        }
        return date.formatted(.dateTime.month(.abbreviated).day().year())
    }
}

private struct PressEvents: ViewModifier {
    let onChange: (Bool) -> Void
    func body(content: Content) -> some View {
        content.simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in onChange(true) }
                .onEnded { _ in onChange(false) }
        )
    }
}

private extension View {
    func pressEvents(_ onChange: @escaping (Bool) -> Void) -> some View {
        modifier(PressEvents(onChange: onChange))
    }
}

#Preview {
    ContentView()
        .environmentObject(AppViewModel())
}

private struct DatePickerPopover: View {
    @Binding var selectedDate: Date
    var onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(selectedDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day().year()))
                    .font(.headline)
                Spacer()
                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            DatePicker(
                "Selected day",
                selection: $selectedDate,
                displayedComponents: [.date]
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
            .focusable(false)
            .tint(Color.accentColor)

            HStack(spacing: 10) {
                Button("Yesterday") {
                    selectedDate = PlanningDateHelpers.calendar.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
                }
                Button("Today") {
                    selectedDate = PlanningDateHelpers.startOfDay(Date())
                }
                Button("Tomorrow") {
                    selectedDate = PlanningDateHelpers.calendar.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                }
                Spacer()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(DS.Surface.card.opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(DS.Surface.hairlineStrong, lineWidth: 1)
        )
    }
}
