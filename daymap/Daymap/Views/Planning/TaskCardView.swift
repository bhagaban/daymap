import SwiftUI

struct TaskCardView: View {
    @EnvironmentObject private var model: AppViewModel

    let task: Task
    var compact: Bool = false
    var tapToEdit: Bool = true
    var onEdit: () -> Void
    var onToggleComplete: () -> Void
    var onToggleStart: () -> Void
    var onOpenFocus: () -> Void

    @State private var celebrate = false
    @State private var isHovered = false

    var body: some View {
        let shadow = DS.Shadow.card(isHovered)
        let radius: CGFloat = compact ? 10 : 12
        let paddingV: CGFloat = compact ? 9 : 10

        return VStack(alignment: .leading, spacing: 6) {
            // Top row: start time + duration pill
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(task.startTime, format: .dateTime.hour().minute())
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
                if task.isRunning {
                    TimelineView(.periodic(from: .now, by: 1)) { timeline in
                        durationPill(timerString(model.displayedSpent(forTaskID: task.id, at: timeline.date)), accent: true)
                    }
                } else {
                    durationPill(durationString, accent: false)
                }
            }

            // Main: title
            Text(task.title.isEmpty ? "Untitled task" : task.title)
                .font(.system(size: compact ? 13 : 14, weight: .medium, design: .rounded))
                .foregroundStyle(task.isCompleted ? .secondary : .primary)
                .strikethrough(task.isCompleted)
                .lineLimit(compact ? 2 : 2)

            // Bottom row: meta + actions
            HStack(spacing: 10) {
                metaText

                Spacer(minLength: 0)

                if task.isRunning {
                    Button(action: onOpenFocus) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .symbolRenderingMode(.monochrome)
                            .foregroundStyle(.secondary)
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .help("Open focus")
                    .contentShape(Rectangle())
                }

                Button(action: onToggleStart) {
                    Image(systemName: task.isRunning ? "pause.circle.fill" : "play.circle.fill")
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(task.isRunning ? Color.primary.opacity(0.85) : .secondary)
                        .font(.title3)
                        .scaleEffect(task.isRunning ? 1.02 : 1.0)
                }
                .buttonStyle(.plain)
                .help(task.isRunning ? "Pause task" : "Start task")
                .contentShape(Rectangle())

                Button(action: onToggleComplete) {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(task.isCompleted ? Color.accentColor : .secondary, .primary)
                        .font(.title3)
                        .scaleEffect(celebrate ? 1.08 : 1.0)
                        .animation(.spring(response: 0.28, dampingFraction: 0.55), value: celebrate)
                }
                .buttonStyle(.plain)
                .help("Mark complete")
                .contentShape(Rectangle())
            }
        }
        .padding(.horizontal, compact ? 12 : 12)
        .padding(.vertical, paddingV)
        .background(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(isHovered ? DS.Surface.cardHover : DS.Surface.card)
                .shadow(color: shadow.0, radius: compact ? (isHovered ? 12 : 10) : shadow.1, x: shadow.2, y: compact ? (isHovered ? 6 : 4) : shadow.3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(isHovered ? DS.Surface.hairlineStrong : DS.Surface.hairline, lineWidth: 1)
        )
        .opacity(task.isCompleted ? 0.92 : 1.0)
        .contentShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .scaleEffect(isHovered ? 1.006 : 1.0)
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: isHovered)
        .onTapGesture {
            guard tapToEdit else { return }
            onEdit()
        }
        .onHover { hovering in
            isHovered = hovering
            model.hoveredTaskID = hovering ? task.id : (model.hoveredTaskID == task.id ? nil : model.hoveredTaskID)
        }
        .animation(.easeInOut(duration: 0.18), value: task.isRunning)
        .onChange(of: task.isCompleted) { _, completed in
            guard completed else { return }
            celebrate = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                celebrate = false
            }
        }
    }

    private var durationString: String {
        let m = Int(task.duration / 60)
        let h = m / 60
        let mm = m % 60
        if h > 0 {
            return "\(h):\(String(format: "%02d", mm))"
        }
        return "0:\(String(format: "%02d", max(1, m)))"
    }

    private func durationPill(_ text: String, accent: Bool) -> some View {
        Text(text)
            .font(.caption2.monospacedDigit())
            .foregroundStyle(accent ? Color.accentColor.opacity(0.85) : .secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(
                Capsule().fill(accent ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.07))
            )
    }

    private func timerString(_ interval: TimeInterval) -> String {
        let s = Int(interval.rounded(.down))
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, sec) }
        return String(format: "%02d:%02d", m, sec)
    }

    private var metaText: some View {
        let total = task.subtasks.count
        let done = task.subtasks.filter(\.isCompleted).count
        let remaining = max(0, total - done)
        let started = task.isRunning || task.actualTimeSpent > 0
        let showProgress = started && done > 0 && total > 0

        return HStack(spacing: 8) {
            if !task.tags.isEmpty {
                Text(task.tags.prefix(3).map { "#\($0)" }.joined(separator: " "))
                    .lineLimit(1)
            } else if total > 0 {
                Text("\(total) subtasks")
            } else {
                Text(" ")
                    .foregroundStyle(.clear)
            }

            if showProgress {
                Text("•")
                    .foregroundStyle(.secondary)

                HStack(spacing: 5) {
                    Image(systemName: "checkmark.circle.fill")
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(Color.accentColor.opacity(0.85))
                        .font(.caption2)
                    Text("\(done) / \(remaining)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.primary.opacity(0.06)))
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
}
