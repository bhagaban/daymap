import SwiftUI

struct ScratchpadView: View {
    @EnvironmentObject private var model: AppViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var mode: Mode = .notes
    @State private var newItemTitle: String = ""
    @FocusState private var itemFieldFocused: Bool

    private enum Mode: String, CaseIterable {
        case notes = "Notes"
        case list = "List"
    }

    var body: some View {
        VStack(spacing: 14) {
            header

            Picker("", selection: $mode) {
                ForEach(Mode.allCases, id: \.self) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 220)

            Group {
                switch mode {
                case .notes:
                    notesPane
                case .list:
                    listPane
                }
            }
        }
        .padding(16)
        .frame(minWidth: 460, minHeight: 520)
        .background(DS.Surface.panelBackground.opacity(0.70))
    }

    private var header: some View {
        HStack(alignment: .center) {
            HStack(spacing: 10) {
                Image(systemName: "note.text")
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(.secondary)
                Text("Scratchpad")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .help("Close")
        }
    }

    private var notesPane: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Freeform")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            TextEditor(text: $model.scratchpad.notes)
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .scrollContentBackground(.hidden)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(DS.Surface.card.opacity(0.92))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(DS.Surface.hairlineStrong, lineWidth: 1)
                )
        }
    }

    private var listPane: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Unscheduled")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Image(systemName: "plus.circle")
                    .foregroundStyle(.secondary)
                TextField("Add an unscheduled task…", text: $newItemTitle)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .focused($itemFieldFocused)
                    .onSubmit { addItem() }
                Spacer(minLength: 0)
                Button("Add") { addItem() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(newItemTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(DS.Surface.card.opacity(0.92))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(DS.Surface.hairlineStrong, lineWidth: 1)
            )

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach($model.scratchpad.items) { $item in
                        ScratchItemRow(item: $item) {
                            removeItem(item.id)
                        }
                    }
                    .onMove(perform: moveItems)
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
            .mask(
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.0),
                        Color.black.opacity(1.0),
                        Color.black.opacity(1.0),
                        Color.black.opacity(0.0),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
            )
        }
    }

    private func addItem() {
        let t = newItemTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        model.scratchpad.items.insert(ScratchItem(title: t), at: 0)
        newItemTitle = ""
        itemFieldFocused = true
    }

    private func removeItem(_ id: UUID) {
        model.scratchpad.items.removeAll { $0.id == id }
    }

    private func moveItems(from: IndexSet, to: Int) {
        model.scratchpad.items.move(fromOffsets: from, toOffset: to)
    }
}

private struct ScratchItemRow: View {
    @Binding var item: ScratchItem
    var onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            Button {
                item.isCompleted.toggle()
            } label: {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(item.isCompleted ? Color.accentColor : .secondary, .primary)
                    .font(.title3)
            }
            .buttonStyle(.plain)

            TextField("Item", text: $item.title)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundStyle(item.isCompleted ? .secondary : .primary)
                .strikethrough(item.isCompleted)

            Spacer(minLength: 0)

            if isHovered {
                Button {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.secondary)
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isHovered ? DS.Surface.cardHover : DS.Surface.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(isHovered ? DS.Surface.hairlineStrong : DS.Surface.hairline, lineWidth: 1)
        )
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.14), value: isHovered)
    }
}

