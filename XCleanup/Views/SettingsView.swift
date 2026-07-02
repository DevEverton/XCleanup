import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @Bindable var appState: AppState
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginItemError: String?

    var body: some View {
        @Bindable var locations = appState.locations
        Form {
            Section {
                Picker("Scan for build artifacts in", selection: $locations.useCustomFolders) {
                    Text("Home folder (automatic)").tag(false)
                    Text("Specific folders only").tag(true)
                }
                .pickerStyle(.radioGroup)
                .onChange(of: locations.useCustomFolders) {
                    appState.refresh(.spmBuild)
                }

                if locations.useCustomFolders {
                    if locations.customRoots.isEmpty {
                        Text("Add at least one folder to scan.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(locations.customRoots, id: \.path) { url in
                        HStack {
                            Text(url.path).lineLimit(1).truncationMode(.middle)
                            Spacer()
                            Button("Remove") {
                                locations.removeProjectRoot(url)
                                appState.refresh(.spmBuild)
                            }
                        }
                    }
                    Button("Add Folder…") {
                        locations.promptToAddProjectRoot()
                        appState.refresh(.spmBuild)
                    }
                }
            } header: {
                Text("Package scanning")
            } footer: {
                Text("The Package Builds category finds Swift package build artifacts (.build folders) in your code. Automatic mode covers everything in your home folder and skips system folders like Library, Music, and Photos. Choose specific folders only if your projects live elsewhere (e.g. an external drive) or to speed up scans.")
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
