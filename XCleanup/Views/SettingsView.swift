import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @Bindable var appState: AppState
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginItemError: String?

    var body: some View {
        Form {
            Section {
                if appState.locations.projectRoots.isEmpty {
                    Text("No folders added — the Package Builds category is idle.").foregroundStyle(.secondary)
                }
                ForEach(appState.locations.projectRoots, id: \.path) { url in
                    HStack {
                        Text(url.path).lineLimit(1).truncationMode(.middle)
                        Spacer()
                        Button("Remove") {
                            appState.locations.removeProjectRoot(url)
                        }
                    }
                }
                Button("Add Folder…") {
                    appState.locations.promptToAddProjectRoot()
                    appState.refresh(.spmBuild)
                }
            } header: {
                Text("Code folders")
            } footer: {
                Text("XCleanup scans these folders for Swift package build artifacts (.build folders), which can silently grow to hundreds of GB. Your home folder is scanned by default; system folders like Library, Music, and Photos are skipped. Narrow it to your projects folder for faster scans.")
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

        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }
}
