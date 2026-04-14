import SwiftUI

struct FocusModeView: View {
    @EnvironmentObject private var model: AppViewModel

    let taskID: UUID
    @State private var appear = false
    @State private var hoveredSubtaskID: UUID? = nil

    var body: some View {
        Group {
            if let task = liveTask {
                content(task: task)
            } else {
                ProgressView().onAppear { model.closeFocus() }
            }
        }
        .onAppear { model.syncFocusTaskFromStore() }
    }

    private var liveTask: Task? {
        model.tasks.first { $0.id == taskID }
    }

    @ViewBuilder
    private func content(task: Task) -> some View {
        ZStack {
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()
                .overlay(Color.black.opacity(0.55))
                .ignoresSafeArea()

            VStack(spacing: 28) {
                Text(task.title.isEmpty ? "Focus" : task.title)
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)

                TimelineView(.periodic(from: .now, by: 1)) { timeline in
                    let spent = model.focusDisplayedSpent(at: timeline.date)
                    VStack(spacing: 10) {
                        Text(formatInterval(spent))
                            .font(.system(size: 52, weight: .light, design: .monospaced))
                            .foregroundStyle(.white)
                            .contentTransition(.numericText())
                            .shadow(color: Color.white.opacity(task.isRunning ? 0.15 : 0.06), radius: task.isRunning ? 22 : 10, x: 0, y: 12)

                        TickingDot(isActive: task.isRunning, date: timeline.date)
                    }
                }

                if !task.subtasks.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Subtasks")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.55))
                        ForEach(task.subtasks) { sub in
                            Button {
                                toggleSubtask(sub.id)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: sub.isCompleted ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(sub.isCompleted ? Color.green : Color.white.opacity(0.35))
                                        .font(.title3)
                                    Text(sub.title)
                                        .foregroundStyle(.white.opacity(sub.isCompleted ? 0.75 : 0.92))
                                        .strikethrough(sub.isCompleted, color: Color.white.opacity(0.35))
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color.white.opacity(hoveredSubtaskID == sub.id ? 0.09 : 0.06))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(Color.white.opacity(hoveredSubtaskID == sub.id ? 0.18 : 0.10), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                            .onHover { hovering in hoveredSubtaskID = hovering ? sub.id : (hoveredSubtaskID == sub.id ? nil : hoveredSubtaskID) }
                            .font(.headline)
                        }
                    }
                    .frame(maxWidth: 520, alignment: .leading)
                    .padding(.horizontal, 24)
                }

                HStack(spacing: 14) {
                    Button(task.isRunning ? "Pause" : "Start") {
                        model.focusToggleTimer()
                    }
                    .keyboardShortcut(.space, modifiers: [])
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button("Complete") {
                        model.focusComplete()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }

                Button("Close") {
                    model.closeFocus()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.55))
                .padding(.top, 8)
            }
            .padding(32)
            .scaleEffect(appear ? 1.0 : 0.985)
            .opacity(appear ? 1.0 : 0.0)
            .animation(.spring(response: 0.34, dampingFraction: 0.86), value: appear)
        }
        .frame(minWidth: 720, minHeight: 520)
        .onAppear { appear = true }
    }

    private func formatInterval(_ interval: TimeInterval) -> String {
        let s = Int(interval.rounded(.down))
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, sec)
        }
        return String(format: "%02d:%02d", m, sec)
    }

    private func toggleSubtask(_ subtaskID: UUID) {
        model.toggleSubtask(taskID: taskID, subtaskID: subtaskID)
    }
}

private struct TickingDot: View {
    let isActive: Bool
    let date: Date

    var body: some View {
        Circle()
            .fill(Color.white.opacity(isActive ? 0.85 : 0.2))
            .frame(width: 8, height: 8)
            .scaleEffect(isActive ? tickScale(for: date) : 1.0)
            .shadow(color: Color.white.opacity(isActive ? 0.25 : 0.0), radius: isActive ? 10 : 0, x: 0, y: 0)
            .animation(.easeInOut(duration: 0.2), value: isActive)
    }

    private func tickScale(for date: Date) -> CGFloat {
        let pulse = abs(sin(date.timeIntervalSinceReferenceDate * .pi))
        return CGFloat(1.0 + 0.12 * pulse)
    }
}

private struct VisualEffectBlur: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = blendingMode
        v.state = .active
        return v
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = .active
    }
}
