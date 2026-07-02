import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @Bindable var appState: AppState
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginItemError: String?

    var body: some View {
        Form {
            Section("Project folders scanned for SwiftPM .build") {
                if appState.bookmarks.projectRoots.isEmpty {
                    Text("No folders added yet.").foregroundStyle(.secondary)
                }
                ForEach(appState.bookmarks.projectRoots, id: \.path) { url in
                    HStack {
                        Text(url.path).lineLimit(1).truncationMode(.middle)
                        Spacer()
                        Button("Remove") {
                            appState.bookmarks.removeProjectRoot(url)
                        }
                    }
                }
                Button("Add Folder…") {
                    appState.bookmarks.promptToAddProjectRoot()
                    appState.refresh(.spmBuild)
                }
            }

            Section("Behavior") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enable in
                        do {
                            if enable {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                            loginItemError = nil
                        } catch {
                            loginItemError = error.localizedDescription
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
                if let loginItemError {
                    Text(loginItemError).font(.caption).foregroundStyle(.red)
                }

                Picker("Refresh sizes automatically", selection: $appState.refreshIntervalHours) {
                    Text("Off").tag(0)
                    Text("Every hour").tag(1)
                    Text("Every 6 hours").tag(6)
                    Text("Every 24 hours").tag(24)
                }
            }

            Section("Access") {
                HStack {
                    Text(appState.bookmarks.developerRoot?.path ?? "Library/Developer access not granted")
                        .lineLimit(1).truncationMode(.middle)
                        .foregroundStyle(appState.hasAccess ? .primary : .secondary)
                    Spacer()
                    Button(appState.hasAccess ? "Re-grant…" : "Grant…") {
                        appState.bookmarks.promptForDeveloperAccess()
                        if appState.hasAccess { appState.refreshAll() }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }
}
