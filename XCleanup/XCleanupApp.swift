import SwiftUI
import XCleanupCore

@main
struct XCleanupApp: App {
    @State private var appState: AppState

    init() {
        let state = AppState()
        AppStateHolder.shared = state
        _appState = State(initialValue: state)
        state.refreshAll()
    }

    var body: some Scene {
        MenuBarExtra("XCleanup", systemImage: "hammer.circle") {
            MenuPanelView(appState: appState)
        }
        .menuBarExtraStyle(.window)

        Window("XCleanup", id: "main") {
            MainWindowView(appState: appState)
        }
        .defaultSize(width: 800, height: 540)

        Settings {
            SettingsView(appState: appState)
        }
    }
}
