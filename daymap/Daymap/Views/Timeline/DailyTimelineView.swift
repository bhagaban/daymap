import SwiftUI

/// Vertical hour grid with draggable / resizable task blocks.
struct DailyTimelineView: View {
    @EnvironmentObject private var model: AppViewModel

    private let startHour = 6
    /// Exclusive upper bound: timeline runs from `startHour` through end of day (midnight).
    private let endHour = 24
    private let hourHeight: CGFloat = 52
    private let contentMaxWidth: CGFloat = 560

    @State private var timelineNow = Date()
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 12) {
                header
                ScrollViewReader { proxy in
                    ScrollView {
                        GeometryReader { geo in
                            let canvasWidth = geo.size.width
                            ZStack(alignment: .topLeading) {
                                timeBands
                                hoursBackground
                                workHoursOverlay
                                let laidOut = layoutTasks(model.tasksSortedByTime(on: model.selectedDate))
                                ForEach(laidOut, id: \.task.id) { item in
                                    TimelineTaskBlock(
                                        task: item.task,
                                        startHour: startHour,
                                        hourHeight: hourHeight,
                                        lane: item.lane,
                                        laneCount: item.laneCount,
                                        isHighlighted: model.hoveredTaskID == item.task.id,
                                        canvasWidth: canvasWidth,
                                        onUpdateStartEnd: { start, end in
                                            model.updateTaskTimes(id: item.task.id, start: start, end: end)
                                        },
                                        onMoveBySeconds: { delta in
                                            model.shiftTaskTimes(id: item.task.id, delta: delta)
                                        }
                                    )
                                }
                                CurrentTimeIndicator(
                                    day: model.selectedDate,
                                    startHour: startHour,
                                    endHour: endHour,
                                    hourHeight: hourHeight
                                )
                                NowScrollMarker(
                                    anchorMinutes: scrollAnchorMinutes,
                                    startHour: startHour,
                                    hourHeight: hourHeight
                                )
                                if model.tasksSortedByTime(on: model.selectedDate).isEmpty {
                                    timelineEmpty
                                }
                            }
                            .frame(width: canvasWidth, height: CGFloat(endHour - startHour) * hourHeight + 24, alignment: .topLeading)
                        }
                        .frame(height: CGFloat(endHour - startHour) * hourHeight + 24)
                        .padding(.horizontal, 10)
                        .padding(.bottom, 24)
                    }
                    .scrollIndicators(.hidden)
                    .onAppear {
                        scrollToNow(proxy: proxy)
                    }
                    .onChange(of: model.selectedDate) { _, _ in
                        scrollToNow(proxy: proxy)
                    }
                }
            }
            .frame(maxWidth: contentMaxWidth)
            // Align content toward the split divider (left edge).
            .padding(.leading, 10)
            .padding(.trailing, 18)
            .padding(.vertical, 16)
            Spacer(minLength: 0)
        }
        .background(DS.Surface.panelBackground.opacity(0.55))
        .onReceive(tick) { timelineNow = $0 }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Time")
                    .font(.headline)
                Text(model.selectedDate.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var timeBands: some View {
        VStack(spacing: 0) {
            ForEach(startHour..<endHour, id: \.self) { hour in
                HStack(alignment: .top, spacing: 10) {
                    Color.clear.frame(width: 54)
                    Rectangle()
                        .fill((hour % 2 == 0) ? Color.primary.opacity(0.035) : Color.clear)
                        .frame(height: hourHeight)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private var hoursBackground: some View {
        VStack(spacing: 0) {
            ForEach(startHour..<endHour, id: \.self) { hour in
                HStack(alignment: .top, spacing: 10) {
                    Text(label(for: hour))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 54, alignment: .trailing)
                    Rectangle()
                        .fill(Color.primary.opacity(0.10))
                        .frame(height: hourHeight)
                }
            }
        }
    }

    private var workHoursOverlay: some View {
        let startM = model.settings.workdayStartMinutes
        let endM = model.settings.workdayEndMinutes
        let startY = yOffset(minutesFromMidnight: startM)
        let endY = yOffset(minutesFromMidnight: endM)
        return Rectangle()
            .fill(Color.accentColor.opacity(0.05))
            .frame(height: max(0, endY - startY))
            .offset(x: 64, y: startY)
            .allowsHitTesting(false)
    }

    private func label(for hour: Int) -> String {
        let d = PlanningDateHelpers.combine(day: model.selectedDate, minutesFromMidnight: hour * 60)
        return d.formatted(Date.FormatStyle().hour(.defaultDigits(amPM: .abbreviated)))
    }

    private func yOffset(minutesFromMidnight: Int) -> CGFloat {
        let minutesFromStart = minutesFromMidnight - startHour * 60
        return CGFloat(minutesFromStart) / 60.0 * hourHeight
    }

    private var scrollAnchorMinutes: Int {
        if PlanningDateHelpers.isSameDay(model.selectedDate, timelineNow) {
            return PlanningDateHelpers.minutesFromMidnight(timelineNow)
        }
        return model.settings.workdayStartMinutes
    }

    private func scrollToNow(proxy: ScrollViewProxy) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            withAnimation(.easeInOut(duration: 0.35)) {
                proxy.scrollTo("now-marker", anchor: UnitPoint(x: 0.5, y: 0.35))
            }
        }
    }

    private var timelineEmpty: some View {
        VStack(spacing: 10) {
            Text("Your day is empty")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("Drag tasks here, or add one on the left.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 120)
        .allowsHitTesting(false)
    }

    private struct LaidOutTask: Hashable {
        let task: Task
        let lane: Int
        let laneCount: Int
    }

    private func layoutTasks(_ tasks: [Task]) -> [LaidOutTask] {
        guard !tasks.isEmpty else { return [] }
        let sorted = tasks.sorted { $0.startTime < $1.startTime }

        struct Active {
            var task: Task
            var lane: Int
        }

        var result: [UUID: (lane: Int, laneCount: Int)] = [:]
        var active: [Active] = []
        var maxLaneInWindow = 1

        for t in sorted {
            active.removeAll { $0.task.endTime <= t.startTime }
            let used = Set(active.map(\.lane))
            var lane = 0
            while used.contains(lane) { lane += 1 }
            active.append(Active(task: t, lane: lane))
            maxLaneInWindow = max(maxLaneInWindow, active.count)

            // Update laneCount for all tasks currently in the window.
            for a in active {
                let existing = result[a.task.id]?.laneCount ?? 1
                result[a.task.id] = (lane: result[a.task.id]?.lane ?? a.lane, laneCount: max(existing, maxLaneInWindow))
            }
            // Ensure current is recorded.
            let existing = result[t.id]?.laneCount ?? 1
            result[t.id] = (lane: lane, laneCount: max(existing, maxLaneInWindow))
        }

        return sorted.map { t in
            let meta = result[t.id] ?? (lane: 0, laneCount: 1)
            return LaidOutTask(task: t, lane: meta.lane, laneCount: max(1, meta.laneCount))
        }
    }
}

private struct NowScrollMarker: View {
    let anchorMinutes: Int
    let startHour: Int
    let hourHeight: CGFloat

    var body: some View {
        let y = CGFloat(anchorMinutes - startHour * 60) / 60.0 * hourHeight
        return Color.clear
            .frame(width: 1, height: 1)
            .offset(x: 80, y: y)
            .id("now-marker")
    }
}

private struct CurrentTimeIndicator: View {
    let day: Date
    let startHour: Int
    let endHour: Int
    let hourHeight: CGFloat

    @State private var now = Date()
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var phase: CGFloat = 0

    var body: some View {
        Group {
            if PlanningDateHelpers.isSameDay(day, now) {
                let minutes = PlanningDateHelpers.minutesFromMidnight(now)
                let y = CGFloat(minutes - startHour * 60) / 60.0 * hourHeight
                let visible = minutes >= startHour * 60 && minutes < endHour * 60
                if visible {
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.red.opacity(0.92))
                            .frame(height: 2.5)
                            .offset(x: 64, y: y)
                            .shadow(color: Color.red.opacity(0.25 + 0.10 * phase), radius: 10, x: 0, y: 0)
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                            .offset(x: 60, y: y - 3)
                            .shadow(color: Color.red.opacity(0.35 + 0.15 * phase), radius: 10, x: 0, y: 0)
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .onReceive(ticker) { now = $0 }
        .onAppear {
            now = Date()
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                phase = 1
            }
        }
    }
}

private struct TimelineTaskBlock: View {
    let task: Task
    let startHour: Int
    let hourHeight: CGFloat
    let lane: Int
    let laneCount: Int
    let isHighlighted: Bool
    let canvasWidth: CGFloat
    let onUpdateStartEnd: (Date, Date) -> Void
    let onMoveBySeconds: (TimeInterval) -> Void

    @State private var dragTranslation: CGFloat = 0
    @State private var previewStart: Date?
    @State private var previewEnd: Date?
    @State private var isDragging = false
    @State private var isResizing = false
    @State private var isHovering = false

    var body: some View {
        let ghostStart = previewStart ?? task.startTime
        let ghostEnd = previewEnd ?? task.endTime

        let baseTop = y(for: task.startTime)
        let baseHeight = max(22, y(for: task.endTime) - baseTop)

        let ghostTop = y(for: ghostStart)
        let ghostHeight = max(22, y(for: ghostEnd) - ghostTop)

        let previewing = previewStart != nil || previewEnd != nil

        let laneInset = CGFloat(min(lane, 3)) * 8
        let laneWidthFactor = max(0.70, 1.0 - CGFloat(max(laneCount - 1, 0)) * 0.10)
        let baseWidthPadding: CGFloat = 8
        let leftGutter: CGFloat = 64
        let available = max(120, canvasWidth - leftGutter - baseWidthPadding)
        let laneWidth = available * laneWidthFactor

        ZStack(alignment: .bottom) {
            if previewing {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.accentColor.opacity(0.22), style: StrokeStyle(lineWidth: 1, dash: [6, 6]))
                    )
                    .frame(height: ghostHeight)
                    .offset(x: 64 + laneInset, y: ghostTop)
                    .padding(.trailing, baseWidthPadding)
                    .allowsHitTesting(false)
            }

            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.teal.opacity(task.isCompleted ? 0.18 : 0.34),
                            Color.teal.opacity(task.isCompleted ? 0.12 : 0.26)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(task.title.isEmpty ? "Untitled" : task.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                        if isResizing || previewing {
                            Text(durationLabel(start: ghostStart, end: ghostEnd))
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .transition(.opacity)
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: baseHeight)
                .shadow(color: .black.opacity(isDragging || isResizing ? 0.18 : 0.10), radius: isDragging || isResizing ? 14 : 10, x: 0, y: isDragging || isResizing ? 10 : 6)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(
                            isHighlighted ? Color.accentColor.opacity(0.55) : Color.white.opacity(previewing ? 0.12 : 0.06),
                            lineWidth: isHighlighted ? 1.4 : (previewing ? 1.2 : 1)
                        )
                )
                .scaleEffect(isDragging ? 1.02 : 1.0)

            // Invisible resize hit-area; show only a subtle affordance on hover/resizing.
            ZStack(alignment: .center) {
                if isHovering || isResizing || previewing {
                    Capsule()
                        .fill(Color.white.opacity(0.22))
                        .frame(width: 26, height: 3)
                        .shadow(color: .black.opacity(0.18), radius: 6, x: 0, y: 2)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }
            }
            .frame(width: 80, height: 18)
            .padding(.bottom, 4)
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture()
                    .onChanged { value in
                        isResizing = true
                        let deltaSeconds = Double(value.translation.height / hourHeight) * 3600.0
                        let snapped = (deltaSeconds / 300.0).rounded() * 300.0
                        let newEnd = PlanningDateHelpers.snapMinutes(task.endTime.addingTimeInterval(snapped))
                        previewStart = task.startTime
                        previewEnd = max(newEnd, task.startTime.addingTimeInterval(15 * 60))
                    }
                    .onEnded { value in
                        let deltaSeconds = Double(value.translation.height / hourHeight) * 3600.0
                        let snappedSeconds = (deltaSeconds / 300.0).rounded() * 300.0
                        let newEnd = PlanningDateHelpers.snapMinutes(task.endTime.addingTimeInterval(snappedSeconds))
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                            onUpdateStartEnd(task.startTime, max(newEnd, task.startTime.addingTimeInterval(15 * 60)))
                            previewStart = nil
                            previewEnd = nil
                            isResizing = false
                        }
                    }
            )
        }
        .frame(width: laneWidth, alignment: .leading)
        .offset(x: leftGutter + laneInset, y: baseTop + dragTranslation)
        .onHover { isHovering = $0 }
        .gesture(
            DragGesture()
                .onChanged { value in
                    isDragging = true
                    dragTranslation = value.translation.height
                    let deltaSeconds = Double(value.translation.height / hourHeight) * 3600.0
                    let snapped = (deltaSeconds / 300.0).rounded() * 300.0
                    let newStart = PlanningDateHelpers.snapMinutes(task.startTime.addingTimeInterval(snapped))
                    let newEnd = newStart.addingTimeInterval(task.duration)
                    previewStart = newStart
                    previewEnd = newEnd
                }
                .onEnded { value in
                    let deltaSeconds = Double(value.translation.height / hourHeight) * 3600.0
                    let snappedSeconds = (deltaSeconds / 300.0).rounded() * 300.0
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        onMoveBySeconds(snappedSeconds)
                        dragTranslation = 0
                        previewStart = nil
                        previewEnd = nil
                        isDragging = false
                    }
                }
        )
        .animation(.easeInOut(duration: 0.10), value: previewStart)
        .animation(.easeInOut(duration: 0.10), value: previewEnd)
        .animation(.easeInOut(duration: 0.18), value: isHighlighted)
    }

    private func y(for date: Date) -> CGFloat {
        let minutes = PlanningDateHelpers.minutesFromMidnight(date)
        return CGFloat(minutes - startHour * 60) / 60.0 * hourHeight
    }

    private func durationLabel(start: Date, end: Date) -> String {
        let secs = max(0, end.timeIntervalSince(start))
        let m = Int(secs / 60)
        let h = m / 60
        let mm = m % 60
        if h > 0 { return "\(h):\(String(format: "%02d", mm))" }
        return "0:\(String(format: "%02d", max(1, mm)))"
    }
}
