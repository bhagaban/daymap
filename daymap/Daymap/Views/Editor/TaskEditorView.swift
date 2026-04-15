import SwiftUI

struct TaskEditorView: View {
    @EnvironmentObject private var model: AppViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var draft: Task
    @FocusState private var focusedField: Field?

    @State private var appear = false
    @State private var isEditingTitle = false

    @State private var newSubtaskTitle: String = ""
    @State private var tagField: String = ""

    @State private var parsed: TaskIntentParser.Result = .empty
    @State private var userTouchedDate = false
    @State private var userTouchedTime = false
    @State private var userTouchedTags = false
    @State private var lastStableDurationMinutes: Int = 30
    @State private var showNotes = false
    @State private var isDatePopoverPresented = false

    private let isNew: Bool

    init(task: Task, isNew: Bool) {
        _draft = State(initialValue: task)
        self.isNew = isNew
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.clear

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        // Title: visible by default, click to inline edit.
                        VStack(alignment: .leading, spacing: 10) {
                            titleInline

                            if !parsed.chips.isEmpty {
                                HStack(spacing: 8) {
                                    ForEach(parsed.chips, id: \.self) { chip in
                                        Chip(text: chip)
                                            .transition(.opacity.combined(with: .move(edge: .top)))
                                    }
                                    Spacer(minLength: 0)
                                }
                                .animation(.easeInOut(duration: 0.18), value: parsed.chips)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(inputSurface(isFocused: focusedField == .title))

                        // Schedule: lightweight date + range, with smart presets
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 10) {
                                Image(systemName: "calendar")
                                    .foregroundStyle(.secondary)
                                Text(dateLabel)
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.secondary)

                                Spacer()

                                Button("Today") { setDateRelative(days: 0) }
                                Button("Tomorrow") { setDateRelative(days: 1) }
                                Button("Next weekday") { setNextWeekday() }
                                Button("Pick…") { isDatePopoverPresented.toggle() }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .popover(isPresented: $isDatePopoverPresented, arrowEdge: .top) {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        Text("Pick a day")
                                            .font(.headline)
                                        Spacer()
                                        Button {
                                            isDatePopoverPresented = false
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundStyle(.secondary)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    
                                    DatePicker(
                                        "",
                                        selection: Binding(
                                            get: { draft.date },
                                            set: { newDay in
                                                userTouchedDate = true
                                                let day = PlanningDateHelpers.startOfDay(newDay)
                                                let dur = currentDurationMinutes
                                                let start = PlanningDateHelpers.dateByMerging(day: day, timeFrom: draft.startTime)
                                                draft.date = day
                                                draft.startTime = start
                                                draft.endTime = PlanningDateHelpers.addMinutes(dur, to: start)
                                                clampEndAfterStart()
                                            }
                                        ),
                                        displayedComponents: [.date]
                                    )
                                    .datePickerStyle(.graphical)
                                    .labelsHidden()
                                    .focusable(false)
                                    .tint(Color.accentColor)
                                }
                                .padding(12)
                                .frame(width: 320)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(DS.Surface.card.opacity(0.92))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .strokeBorder(DS.Surface.hairlineStrong, lineWidth: 1)
                                )
                            }

                            HStack(spacing: 10) {
                                Image(systemName: "clock")
                                    .foregroundStyle(.secondary)

                                DatePicker("", selection: Binding(
                                    get: { draft.startTime },
                                    set: { newValue in
                                        userTouchedTime = true
                                        let dur = currentDurationMinutes
                                        draft.startTime = newValue
                                        draft.endTime = PlanningDateHelpers.addMinutes(dur, to: newValue)
                                        clampEndAfterStart()
                                    }
                                ), displayedComponents: [.hourAndMinute])
                                .labelsHidden()
                                .datePickerStyle(.field)
                                .frame(width: 110)

                                Text("→")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                DatePicker("", selection: Binding(
                                    get: { draft.endTime },
                                    set: { newValue in
                                        userTouchedTime = true
                                        draft.endTime = newValue
                                        clampEndAfterStart()
                                        lastStableDurationMinutes = currentDurationMinutes
                                    }
                                ), displayedComponents: [.hourAndMinute])
                                .labelsHidden()
                                .datePickerStyle(.field)
                                .frame(width: 110)

                                Spacer()

                                HStack(spacing: 6) {
                                    Button("+15m") { bumpDuration(15) }
                                    Button("+30m") { bumpDuration(30) }
                                    Button("+1h") { bumpDuration(60) }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }

                            if draft.endTime <= draft.startTime {
                                Text("End time adjusted to be after start.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .transition(.opacity)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(inputSurface(isFocused: false))
                        .animation(.easeInOut(duration: 0.18), value: draft.startTime)
                        .animation(.easeInOut(duration: 0.18), value: draft.endTime)

                        // Subtasks: collapsed until used
                        if !draft.subtasks.isEmpty || focusedField == .subtask || !newSubtaskTitle.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Subtasks")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)

                                VStack(spacing: 8) {
                                    ForEach($draft.subtasks) { $sub in
                                        HStack(spacing: 10) {
                                            Button {
                                                sub.isCompleted.toggle()
                                            } label: {
                                                Image(systemName: sub.isCompleted ? "checkmark.circle.fill" : "circle")
                                                    .symbolRenderingMode(.palette)
                                                    .foregroundStyle(sub.isCompleted ? Color.accentColor : .secondary, .primary)
                                                    .font(.title3)
                                            }
                                            .buttonStyle(.plain)

                                            TextField("Subtask", text: $sub.title)
                                                .textFieldStyle(.plain)
                                                .font(.system(size: 13, weight: .regular, design: .rounded))

                                            Button {
                                                removeSubtask(sub.id)
                                            } label: {
                                                Image(systemName: "xmark")
                                                    .font(.caption.weight(.semibold))
                                                    .foregroundStyle(.secondary)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.55))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .strokeBorder(Color.white.opacity(0.05), lineWidth: 1)
                                        )
                                    }

                                    HStack(spacing: 10) {
                                        Image(systemName: "plus.circle")
                                            .foregroundStyle(.secondary)
                                        TextField("Add a subtask", text: $newSubtaskTitle)
                                            .textFieldStyle(.plain)
                                            .font(.system(size: 13, weight: .regular, design: .rounded))
                                            .focused($focusedField, equals: .subtask)
                                            .onSubmit { addSubtask() }

                                        Spacer()
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(Color(nsColor: .controlBackgroundColor).opacity(0.55))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .strokeBorder(Color.white.opacity(0.05), lineWidth: 1)
                                    )
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(inputSurface(isFocused: focusedField == .subtask))
                            .transition(.opacity.combined(with: .move(edge: .top)))
                            .animation(.easeInOut(duration: 0.20), value: draft.subtasks.count)
                        }

                        // Notes: lightweight, only if used
                        if showNotes || (draft.notes?.isEmpty == false) || focusedField == .notes {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Notes")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                TextField(
                                    "Add notes…",
                                    text: Binding(
                                        get: { draft.notes ?? "" },
                                        set: { draft.notes = $0.isEmpty ? nil : $0 }
                                    ),
                                    axis: .vertical
                                )
                                .textFieldStyle(.plain)
                                .lineLimit(2...8)
                                .font(.system(size: 13, weight: .regular, design: .rounded))
                                .focused($focusedField, equals: .notes)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(inputSurface(isFocused: focusedField == .notes))
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        } else {
                            Button {
                                focusedField = .notes
                                if draft.notes == nil { draft.notes = "" }
                                showNotes = true
                            } label: {
                                Label("Add notes", systemImage: "note.text")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .contentShape(Rectangle())
                            .padding(.horizontal, 4)
                        }

                        // Tags: inferred from title, editable as pills
                        if !draft.tags.isEmpty || !tagField.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Tags")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)

                                if !draft.tags.isEmpty {
                                    FlowTags(tags: $draft.tags)
                                }

                                HStack(spacing: 10) {
                                    Image(systemName: "number")
                                        .foregroundStyle(.secondary)
                                    TextField("Add tags (comma separated)", text: $tagField)
                                        .textFieldStyle(.plain)
                                        .font(.system(size: 13, weight: .regular, design: .rounded))
                                        .onSubmit { applyTagsFromField() }
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.55))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.05), lineWidth: 1)
                                )
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(inputSurface(isFocused: false))
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        Spacer(minLength: 6)
                    }
                    .padding(16)
                }
                // Clicking anywhere in the editor (outside the title field) exits inline title edit.
                .background(
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            guard isEditingTitle else { return }
                            isEditingTitle = false
                            if focusedField == .title {
                                focusedField = nil
                            }
                        }
                )
            }
            .navigationTitle("")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    titleBar
                        .frame(maxWidth: 420)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .keyboardShortcut(.defaultAction)
                        .keyboardShortcut(.return, modifiers: [.command])
                        .disabled(draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                ToolbarItem(placement: .destructiveAction) {
                    if !isNew {
                        Button("Delete", role: .destructive) {
                            model.delete(draft)
                            dismiss()
                        }
                    }
                }
            }
        }
        .frame(minWidth: 560, minHeight: 520)
        .opacity(appear ? 1 : 0)
        .scaleEffect(appear ? 1.0 : 0.96)
        .animation(.spring(response: 0.34, dampingFraction: 0.88), value: appear)
        .onChange(of: focusedField) { _, newValue in
            // If focus moves away from the title field, exit inline title edit.
            if isEditingTitle, newValue != .title {
                isEditingTitle = false
            }
        }
        .onAppear {
            appear = true
            isEditingTitle = isNew
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                focusedField = isEditingTitle ? .title : nil
                parseAndApply(initial: true)
            }
        }
    }

    @ViewBuilder
    private var titleBar: some View {
        if isEditingTitle {
            TextField("Task", text: $draft.title)
                .textFieldStyle(.plain)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .focused($focusedField, equals: .title)
                .onChange(of: draft.title) { _, _ in
                    parseAndApply()
                }
                .onSubmit {
                    isEditingTitle = false
                    focusedField = nil
                }
                .onExitCommand {
                    isEditingTitle = false
                    focusedField = nil
                }
        } else {
            let display = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
            Button {
                isEditingTitle = true
                DispatchQueue.main.async {
                    focusedField = .title
                }
            } label: {
                HStack(spacing: 8) {
                    Text(display.isEmpty ? (isNew ? "New Task" : "Untitled task") : display)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(display.isEmpty ? .secondary : .primary)
                        .lineLimit(1)
                    Image(systemName: "pencil")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Click to edit title")
        }
    }

    @ViewBuilder
    private var titleInline: some View {
        if isEditingTitle {
            TextField(
                "Task title",
                text: $draft.title
            )
            .textFieldStyle(.plain)
            .font(.system(size: 18, weight: .semibold, design: .rounded))
            .focused($focusedField, equals: .title)
            .onChange(of: draft.title) { _, _ in
                parseAndApply()
            }
            .onSubmit {
                isEditingTitle = false
                focusedField = nil
            }
            .onExitCommand {
                isEditingTitle = false
                focusedField = nil
            }
        } else {
            let display = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
            Button {
                isEditingTitle = true
                DispatchQueue.main.async {
                    focusedField = .title
                }
            } label: {
                Text(display.isEmpty ? (isNew ? "New Task" : "Untitled task") : display)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(display.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Click to edit title")
        }
    }

    private func addSubtask() {
        let title = newSubtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        draft.subtasks.append(Subtask(title: title))
        newSubtaskTitle = ""
    }

    private func removeSubtask(_ id: UUID) {
        draft.subtasks.removeAll { $0.id == id }
    }

    private func applyTagsFromField() {
        userTouchedTags = true
        let parts = tagField
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        for p in parts {
            if !draft.tags.contains(p) {
                draft.tags.append(p)
            }
        }
        tagField = ""
    }

    private func save() {
        // Apply a final parse pass so we store a clean title + extracted tags.
        parseAndApply()

        let day = PlanningDateHelpers.startOfDay(draft.date)
        draft.date = day
        // Normalize times onto the task's day while supporting "spills past midnight".
        let mergedStart = PlanningDateHelpers.dateByMerging(day: day, timeFrom: draft.startTime)
        var mergedEnd = PlanningDateHelpers.dateByMerging(day: day, timeFrom: draft.endTime)
        if mergedEnd <= mergedStart {
            // If the user picked an end time like 12:15 AM for a late-night task,
            // interpret it as next day rather than a negative duration.
            mergedEnd = PlanningDateHelpers.calendar.date(byAdding: .day, value: 1, to: mergedEnd) ?? mergedEnd
        }
        if mergedEnd <= mergedStart {
            mergedEnd = mergedStart.addingTimeInterval(30 * 60)
        }
        draft.startTime = mergedStart
        draft.endTime = mergedEnd

        if let cleaned = parsed.cleanedTitle, !cleaned.isEmpty {
            draft.title = cleaned
        }
        model.upsert(draft)
        dismiss()
    }

    private enum Field {
        case title
        case subtask
        case notes
    }

    private var dateLabel: String {
        if PlanningDateHelpers.isSameDay(draft.date, Date()) { return "Today" }
        let tomorrow = PlanningDateHelpers.calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        if PlanningDateHelpers.isSameDay(draft.date, tomorrow) { return "Tomorrow" }
        return draft.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }

    private var currentDurationMinutes: Int {
        max(15, Int((draft.endTime.timeIntervalSince(draft.startTime) / 60.0).rounded()))
    }

    private func bumpDuration(_ minutes: Int) {
        userTouchedTime = true
        lastStableDurationMinutes = minutes
        draft.endTime = PlanningDateHelpers.addMinutes(minutes, to: draft.startTime)
        clampEndAfterStart()
    }

    private func clampEndAfterStart() {
        if draft.endTime <= draft.startTime {
            draft.endTime = PlanningDateHelpers.addMinutes(max(15, lastStableDurationMinutes), to: draft.startTime)
        }
    }

    private func setDateRelative(days: Int) {
        userTouchedDate = true
        let base = PlanningDateHelpers.startOfDay(Date())
        let nextDay = PlanningDateHelpers.calendar.date(byAdding: .day, value: days, to: base) ?? base
        let dur = currentDurationMinutes
        let start = PlanningDateHelpers.dateByMerging(day: nextDay, timeFrom: draft.startTime)
        draft.date = nextDay
        draft.startTime = start
        draft.endTime = PlanningDateHelpers.addMinutes(dur, to: start)
        clampEndAfterStart()
    }

    private func setNextWeekday() {
        userTouchedDate = true
        var d = PlanningDateHelpers.startOfDay(Date())
        while PlanningDateHelpers.calendar.isDateInWeekend(d) {
            d = PlanningDateHelpers.calendar.date(byAdding: .day, value: 1, to: d) ?? d
        }
        // If today is weekday, pick next weekday (not today).
        d = PlanningDateHelpers.calendar.date(byAdding: .day, value: 1, to: d) ?? d
        while PlanningDateHelpers.calendar.isDateInWeekend(d) {
            d = PlanningDateHelpers.calendar.date(byAdding: .day, value: 1, to: d) ?? d
        }
        let dur = currentDurationMinutes
        let start = PlanningDateHelpers.dateByMerging(day: d, timeFrom: draft.startTime)
        draft.date = d
        draft.startTime = start
        draft.endTime = PlanningDateHelpers.addMinutes(dur, to: start)
        clampEndAfterStart()
    }

    private func inputSurface(isFocused: Bool) -> some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor).opacity(0.62))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(isFocused ? Color.accentColor.opacity(0.35) : Color.white.opacity(0.06), lineWidth: isFocused ? 1.2 : 1)
            )
            .shadow(color: .black.opacity(0.10), radius: 14, x: 0, y: 8)
    }

    private func parseAndApply(initial: Bool = false) {
        let baseDay = PlanningDateHelpers.startOfDay(draft.date)
        parsed = TaskIntentParser.parse(draft.title, reference: Date(), baseDay: baseDay)

        if !userTouchedTags, !parsed.tags.isEmpty {
            for t in parsed.tags where !draft.tags.contains(t) {
                draft.tags.append(t)
            }
        }

        // When editing an existing task, the initial parse pass should be display-only.
        // We still show chips and can infer tags, but we must not override saved date/time.
        if initial, !isNew {
            return
        }

        // Apply date if detected and user hasn't manually set it.
        if let parsedDay = parsed.day, !userTouchedDate {
            let dur = currentDurationMinutes
            draft.date = PlanningDateHelpers.startOfDay(parsedDay)
            draft.startTime = PlanningDateHelpers.dateByMerging(day: draft.date, timeFrom: draft.startTime)
            draft.endTime = PlanningDateHelpers.addMinutes(dur, to: draft.startTime)
        }

        // Apply time/duration if detected (even if user touched, the command intent is explicit).
        if let start = parsed.startTime {
            let dur = parsed.durationMinutes ?? lastStableDurationMinutes
            lastStableDurationMinutes = dur
            userTouchedTime = true
            draft.startTime = PlanningDateHelpers.dateByMerging(day: PlanningDateHelpers.startOfDay(draft.date), timeFrom: start)
            draft.endTime = PlanningDateHelpers.addMinutes(dur, to: draft.startTime)
        } else if let dur = parsed.durationMinutes, !userTouchedTime {
            lastStableDurationMinutes = dur
            draft.endTime = PlanningDateHelpers.addMinutes(dur, to: draft.startTime)
        } else if initial, isNew, !userTouchedTime {
            // Smart default: if the user didn't type time, ensure we start at the next available slot.
            let slot = model.nextDefaultSlot(on: PlanningDateHelpers.startOfDay(draft.date))
            draft.startTime = slot.start
            draft.endTime = slot.end
            lastStableDurationMinutes = max(15, Int((slot.end.timeIntervalSince(slot.start) / 60.0).rounded()))
        }

        clampEndAfterStart()
    }
}

private struct FlowTags: View {
    @Binding var tags: [String]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 8)], spacing: 8) {
            ForEach(Array(tags.enumerated()), id: \.offset) { idx, tag in
                HStack(spacing: 6) {
                    Text("#\(tag)")
                        .font(.caption)
                    Button {
                        tags.remove(at: idx)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.secondary.opacity(0.12)))
            }
        }
    }
}

private struct Chip: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(Color.primary.opacity(0.07))
            )
    }
}

private enum TaskIntentParser {
    struct Result: Equatable {
        var day: Date? = nil
        var startTime: Date? = nil
        var durationMinutes: Int? = nil
        var tags: [String] = []
        var cleanedTitle: String? = nil

        var chips: [String] {
            var c: [String] = []
            if let d = day {
                if PlanningDateHelpers.isSameDay(d, Date()) {
                    c.append("Today")
                } else {
                    let tomorrow = PlanningDateHelpers.calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
                    if PlanningDateHelpers.isSameDay(d, tomorrow) {
                        c.append("Tomorrow")
                    } else {
                        c.append(d.formatted(.dateTime.weekday(.abbreviated)))
                    }
                }
            }
            if let t = startTime {
                c.append(t.formatted(.dateTime.hour().minute()))
            }
            if let m = durationMinutes {
                c.append(formatDuration(m))
            }
            return c
        }

        static let empty = Result()
    }

    static func parse(_ raw: String, reference: Date, baseDay: Date) -> Result {
        let input = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return .empty }

        var result = Result()

        // Tags (#strategy)
        let tagRegex = try? NSRegularExpression(pattern: #"(?<!\w)#([A-Za-z0-9_]+)"#, options: [])
        if let tagRegex {
            let ns = input as NSString
            let matches = tagRegex.matches(in: input, options: [], range: NSRange(location: 0, length: ns.length))
            result.tags = matches.compactMap { m in
                guard m.numberOfRanges > 1 else { return nil }
                return ns.substring(with: m.range(at: 1)).lowercased()
            }
        }

        // Date keywords (match whole tokens, not substrings inside other words)
        let lower = input.lowercased()
        let wordTokens = tokenizeWords(lower)
        if wordTokens.contains("tomorrow") {
            result.day = PlanningDateHelpers.calendar.date(byAdding: .day, value: 1, to: PlanningDateHelpers.startOfDay(reference))
        } else if wordTokens.contains("today") {
            result.day = PlanningDateHelpers.startOfDay(reference)
        } else if let weekday = parseWeekday(tokens: wordTokens) {
            result.day = next(weekday: weekday, from: reference)
        }

        // Time (2pm, 14:00)
        if let t = parseTime(lower) {
            // merge into base day; day will be applied separately by caller
            result.startTime = PlanningDateHelpers.dateByMerging(day: baseDay, timeFrom: t)
        }

        // Duration (1h, 30m, 1h30m)
        result.durationMinutes = parseDurationMinutes(lower)

        // Clean title: remove obvious tokens (#tags, today/tomorrow/weekday, time, duration)
        var cleaned = input
        cleaned = cleaned.replacingOccurrences(of: #"(?<!\w)#([A-Za-z0-9_]+)"#, with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"(?i)\b(today|tomorrow)\b"#, with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"(?i)\b(mon(day)?|tue(s(day)?)?|wed(nesday)?|thu(rs(day)?)?|fri(day)?|sat(urday)?|sun(day)?)\b"#, with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"(?i)\b(\d{1,2})(:\d{2})?\s?(am|pm)\b"#, with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"\b([01]?\d|2[0-3]):[0-5]\d\b"#, with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"(?i)\b(\d+\s*(h|hr|hrs|hour|hours))(\s*\d+\s*(m|min|mins|minute|minutes))?\b"#, with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"(?i)\b\d+\s*(m|min|mins|minute|minutes)\b"#, with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        result.cleanedTitle = cleaned.isEmpty ? nil : cleaned

        return result
    }

    private static func parseTime(_ lower: String) -> Date? {
        // 12h: 2pm / 2:30pm
        if let re = try? NSRegularExpression(pattern: #"(?i)\b(\d{1,2})(?::(\d{2}))?\s?(am|pm)\b"#, options: []) {
            let ns = lower as NSString
            if let m = re.firstMatch(in: lower, options: [], range: NSRange(location: 0, length: ns.length)) {
                let h = Int(ns.substring(with: m.range(at: 1))) ?? 0
                let min = m.range(at: 2).location != NSNotFound ? (Int(ns.substring(with: m.range(at: 2))) ?? 0) : 0
                let ampm = ns.substring(with: m.range(at: 3)).lowercased()
                var hour = h % 12
                if ampm == "pm" { hour += 12 }
                let base = PlanningDateHelpers.startOfDay(Date())
                return PlanningDateHelpers.calendar.date(bySettingHour: hour, minute: min, second: 0, of: base)
            }
        }

        // 24h: 14:00
        if let re = try? NSRegularExpression(pattern: #"\b([01]?\d|2[0-3]):([0-5]\d)\b"#, options: []) {
            let ns = lower as NSString
            if let m = re.firstMatch(in: lower, options: [], range: NSRange(location: 0, length: ns.length)) {
                let hour = Int(ns.substring(with: m.range(at: 1))) ?? 0
                let min = Int(ns.substring(with: m.range(at: 2))) ?? 0
                let base = PlanningDateHelpers.startOfDay(Date())
                return PlanningDateHelpers.calendar.date(bySettingHour: hour, minute: min, second: 0, of: base)
            }
        }

        return nil
    }

    private static func parseDurationMinutes(_ lower: String) -> Int? {
        // 1h30m / 1h / 30m
        var minutes = 0

        if let re = try? NSRegularExpression(pattern: #"(?i)\b(\d+)\s*(h|hr|hrs|hour|hours)\b"#, options: []) {
            let ns = lower as NSString
            if let m = re.firstMatch(in: lower, options: [], range: NSRange(location: 0, length: ns.length)) {
                let h = Int(ns.substring(with: m.range(at: 1))) ?? 0
                minutes += h * 60
            }
        }
        if let re = try? NSRegularExpression(pattern: #"(?i)\b(\d+)\s*(m|min|mins|minute|minutes)\b"#, options: []) {
            let ns = lower as NSString
            if let m = re.firstMatch(in: lower, options: [], range: NSRange(location: 0, length: ns.length)) {
                let mVal = Int(ns.substring(with: m.range(at: 1))) ?? 0
                minutes += mVal
            }
        }

        return minutes > 0 ? max(15, minutes) : nil
    }

    private static func tokenizeWords(_ lower: String) -> Set<String> {
        // Split on non-letters so "saturday's" => ["saturday"] and we never match inside "satisfaction".
        Set(lower.split(whereSeparator: { !$0.isLetter }).map { String($0) }.filter { !$0.isEmpty })
    }

    private static func parseWeekday(tokens: Set<String>) -> Int? {
        // Calendar weekday: 1 = Sunday ... 7 = Saturday
        let map: [String: Int] = [
            "sun": 1, "sunday": 1,
            "mon": 2, "monday": 2,
            "tue": 3, "tues": 3, "tuesday": 3,
            "wed": 4, "wednesday": 4,
            "thu": 5, "thur": 5, "thurs": 5, "thursday": 5,
            "fri": 6, "friday": 6,
            "sat": 7, "saturday": 7,
        ]
        for t in tokens {
            if let v = map[t] { return v }
        }
        return nil
    }

    private static func next(weekday: Int, from reference: Date) -> Date {
        let cal = PlanningDateHelpers.calendar
        let start = PlanningDateHelpers.startOfDay(reference)
        let current = cal.component(.weekday, from: start)
        var delta = (weekday - current + 7) % 7
        if delta == 0 { delta = 7 } // "friday" means next friday, not today
        return cal.date(byAdding: .day, value: delta, to: start) ?? start
    }

    private static func formatDuration(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h > 0 && m > 0 { return "\(h)h \(m)m" }
        if h > 0 { return "\(h)h" }
        return "\(m)m"
    }
}
