import SwiftUI

@main
struct DaymapApp: App {
    @StateObject private var model = AppViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .preferredColorScheme(model.settings.appearance == .dark ? .dark : .light)
        }
        .commands {
            CommandMenu("Planning") {
                Button("New Task") {
                    model.openNewTaskEditor(for: model.selectedDate)
                }
                .keyboardShortcut("n", modifiers: [])

                Divider()

                Button("Start / Pause Focus") {
                    model.focusToggleTimer()
                }
                .keyboardShortcut(.space, modifiers: [])
                .disabled(model.focusTask == nil)
            }
        }
    }
}
