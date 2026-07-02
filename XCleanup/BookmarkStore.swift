import AppKit
import Foundation
import Observation

@Observable
final class BookmarkStore {
    private static let developerKey = "bookmark.developer"
    private static let projectsKey = "bookmark.projects"

    private let defaults: UserDefaults
    private(set) var developerRoot: URL?
    private(set) var projectRoots: [URL] = []

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        reload()
    }

    func reload() {
        developerRoot = resolve(defaults.data(forKey: Self.developerKey), persistRefreshTo: Self.developerKey)
        let list = defaults.array(forKey: Self.projectsKey) as? [Data] ?? []
        projectRoots = list.compactMap { resolve($0, persistRefreshTo: nil) }
    }

    func promptForDeveloperAccess() {
        let developerDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Developer", isDirectory: true)
        guard let url = runOpenPanel(
            startingAt: developerDir,
            message: "XCleanup needs access to your Library/Developer folder to measure and clean build artifacts.") else { return }
        if let data = bookmarkData(for: url) {
            defaults.set(data, forKey: Self.developerKey)
            reload()
        }
    }

    func promptToAddProjectRoot() {
        guard let url = runOpenPanel(
            startingAt: FileManager.default.homeDirectoryForCurrentUser,
            message: "Choose a folder to scan for SwiftPM .build directories.") else { return }
        guard let data = bookmarkData(for: url) else { return }
        var list = defaults.array(forKey: Self.projectsKey) as? [Data] ?? []
        list.append(data)
        defaults.set(list, forKey: Self.projectsKey)
        reload()
    }

    func removeProjectRoot(_ url: URL) {
        let list = defaults.array(forKey: Self.projectsKey) as? [Data] ?? []
        let remaining = list.filter { resolve($0, persistRefreshTo: nil)?.path != url.path }
        defaults.set(remaining, forKey: Self.projectsKey)
        reload()
    }

    private func runOpenPanel(startingAt directory: URL, message: String) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = directory
        panel.message = message
        panel.prompt = "Grant Access"
        return panel.runModal() == .OK ? panel.url : nil
    }

    private func bookmarkData(for url: URL) -> Data? {
        try? url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil)
    }

    /// Resolves a bookmark. When stale, tries to mint fresh bookmark data;
    /// if that fails the bookmark is treated as lost (nil), which routes the
    /// UI back to the grant flow.
    private func resolve(_ data: Data?, persistRefreshTo key: String?) -> URL? {
        guard let data else { return nil }
        var stale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &stale) else { return nil }
        guard stale else { return url }
        guard url.startAccessingSecurityScopedResource() else { return nil }
        defer { url.stopAccessingSecurityScopedResource() }
        guard let fresh = bookmarkData(for: url) else { return nil }
        if let key { defaults.set(fresh, forKey: key) }
        return url
    }
}
