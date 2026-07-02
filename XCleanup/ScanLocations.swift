import AppKit
import Foundation
import Observation

@Observable
final class ScanLocations {
    private static let projectsKey = "scan.projectRoots"

    private let defaults: UserDefaults
    private(set) var projectRoots: [URL] = []

    let developerRoot = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Developer", isDirectory: true)

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if defaults.object(forKey: Self.projectsKey) == nil {
            defaults.set([FileManager.default.homeDirectoryForCurrentUser.path], forKey: Self.projectsKey)
        }
        reload()
    }

    func reload() {
        let paths = defaults.stringArray(forKey: Self.projectsKey) ?? []
        projectRoots = paths.map { URL(fileURLWithPath: $0, isDirectory: true) }
    }

    func promptToAddProjectRoot() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
        panel.message = "Choose a folder to scan for Swift package build folders (.build)."
        panel.prompt = "Add"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        var paths = defaults.stringArray(forKey: Self.projectsKey) ?? []
        guard !paths.contains(url.path) else { return }
        paths.append(url.path)
        defaults.set(paths, forKey: Self.projectsKey)
        reload()
    }

    func removeProjectRoot(_ url: URL) {
        let paths = (defaults.stringArray(forKey: Self.projectsKey) ?? []).filter { $0 != url.path }
        defaults.set(paths, forKey: Self.projectsKey)
        reload()
    }
}
