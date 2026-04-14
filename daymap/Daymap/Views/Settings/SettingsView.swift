import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    sectionTitle("Appearance")

                    InlineSettingRow(icon: "moon.stars", title: "Theme") {
                        Picker("", selection: $model.settings.appearance) {
                            Text("Dark").tag(AppearancePreference.dark)
                            Text("Light").tag(AppearancePreference.light)
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .frame(width: 220)
                    }

                    divider

                    sectionTitle("Workday guides")

                    InlineSettingRow(icon: "sunrise", title: "Start") {
                        DatePicker(
                            "",
                            selection: Binding(
                                get: { minutesDate(model.settings.workdayStartMinutes) },
                                set: { model.settings.workdayStartMinutes = minutesFromDate($0) }
                            ),
                            displayedComponents: [.hourAndMinute]
                        )
                        .labelsHidden()
                        .datePickerStyle(.compact)
                    }

                    InlineSettingRow(icon: "sunset", title: "End") {
                        DatePicker(
                            "",
                            selection: Binding(
                                get: { minutesDate(model.settings.workdayEndMinutes) },
                                set: { model.settings.workdayEndMinutes = minutesFromDate($0) }
                            ),
                            displayedComponents: [.hourAndMinute]
                        )
                        .labelsHidden()
                        .datePickerStyle(.compact)
                    }

                    Text("These are visual guides only. Tasks may extend outside this window.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 30)

                    Spacer(minLength: 0)
                }
                .padding(18)
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
        .frame(minWidth: 460, minHeight: 360)
    }

    private func minutesDate(_ minutes: Int) -> Date {
        PlanningDateHelpers.combine(day: Date(), minutesFromMidnight: minutes)
    }

    private func minutesFromDate(_ date: Date) -> Int {
        PlanningDateHelpers.minutesFromMidnight(date)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.top, 2)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.10))
            .frame(height: 1)
            .padding(.vertical, 6)
    }
}

private struct InlineSettingRow<Content: View>: View {
    let icon: String
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 18)

            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .leading)

            Spacer()

            content()
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
