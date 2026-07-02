import AppKit
import Foundation
import Observation

@Observable
final class ScanLocations {
    private static let projectsKey = "scan.projectRoots"
    private static let customModeKey = "scan.useCustomFolders"

    private let defaults: UserDefaults
    private let homeRoot = FileManager.default.homeDirectoryForCurrentUser

    private(set) var customRoots: [URL] = []
    var useCustomFolders: Bool {
        didSet { defaults.set(useCustomFolders, forKey: Self.customModeKey) }
    }

    let developerRoot = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Developer", isDirectory: true)

    /// Automatic mode scans the home folder (system folders are skipped by
    /// BuildFolderScanner); custom mode scans only the folders the user added.
    var projectRoots: [URL] {
        useCustomFolders ? customRoots : [homeRoot]
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        useCustomFolders = defaults.bool(forKey: Self.customModeKey)
        reload()
    }

    func reload() {
        let paths = defaults.stringArray(forKey: Self.projectsKey) ?? []
        customRoots = paths.map { URL(fileURLWithPath: $0, isDirectory: true) }
    }

    func promptToAddProjectRoot() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = homeRoot
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
