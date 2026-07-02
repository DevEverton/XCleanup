import SwiftUI
import XCleanupCore

@main
struct XCleanupApp: App {
    @State private var appState: AppState

    init() {
        let state = AppState()
        AppStateHolder.shared = state
        _appState = State(initialValue: state)
        if state.hasAccess { state.refreshAll() }
    }

    var body: some Scene {
        MenuBarExtra("XCleanup", systemImage: "hammer.circle") {
            MenuPanelView(appState: appState)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(appState: appState)
        }
    }
}
