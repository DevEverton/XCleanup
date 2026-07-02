import Foundation
import Observation
import XCleanupCore

@Observable
final class AppState {
    struct CategoryState: Identifiable {
        let category: CleanupCategory
        var result: ScanResult?
        var isBusy = false
        var failures: [CleanFailure] = []
        var id: CategoryID { category.id }
    }

    let bookmarks = BookmarkStore()
    private(set) var states: [CategoryState]
    var refreshIntervalHours: Int {
        didSet {
            UserDefaults.standard.set(refreshIntervalHours, forKey: "refresh.hours")
            scheduleTimer()
        }
    }

    private var timer: Timer?

    init() {
        states = allCategories.map { CategoryState(category: $0) }
        let stored = UserDefaults.standard.object(forKey: "refresh.hours") as? Int
        refreshIntervalHours = stored ?? 6
        loadCache()
        scheduleTimer()
    }

    var hasAccess: Bool { bookmarks.developerRoot != nil }

    func state(for id: CategoryID) -> CategoryState? {
        states.first { $0.id == id }
    }

    func refreshAll() {
        for id in CategoryID.allCases { refresh(id) }
    }

    func refresh(_ id: CategoryID) {
        guard let ctx = context(),
              let index = states.firstIndex(where: { $0.id == id }),
              !states[index].isBusy else { return }
        states[index].isBusy = true
        let scan = states[index].category.scan
        Task {
            let result = await Self.withRootAccess(ctx: ctx) { scan(ctx) }
            if let idx = self.states.firstIndex(where: { $0.id == id }) {
                self.states[idx].result = result
                self.states[idx].isBusy = false
            }
            self.saveCache()
        }
    }

    func clean(_ id: CategoryID, items: [ScanItem]) {
        guard let ctx = context(),
              let index = states.firstIndex(where: { $0.id == id }),
              !states[index].isBusy, !items.isEmpty else { return }
        states[index].isBusy = true
        Task {
            let outcome = await Self.withRootAccess(ctx: ctx) {
                Deleter.delete(items: items, allowedRoots: ctx.allRoots)
            }
            if let idx = self.states.firstIndex(where: { $0.id == id }) {
                self.states[idx].failures = outcome.failures
                self.states[idx].isBusy = false
            }
            self.refresh(id)
        }
    }

    func eraseSimulator(_ item: ScanItem) {
        guard let ctx = context() else { return }
        let dataURL = item.url.appendingPathComponent("data", isDirectory: true)
        Task {
            let outcome = await Self.withRootAccess(ctx: ctx) {
                Deleter.eraseContents(of: dataURL, allowedRoots: ctx.allRoots)
            }
            if let idx = self.states.firstIndex(where: { $0.id == .simulators }) {
                self.states[idx].failures = outcome.failures
            }
            self.refresh(.simulators)
        }
    }

    private func context() -> ScanContext? {
        guard let developerRoot = bookmarks.developerRoot else { return nil }
        return ScanContext(developerRoot: developerRoot, projectRoots: bookmarks.projectRoots)
    }

    /// Runs `work` on a background task with security-scoped access started
    /// on every granted root for the duration.
    nonisolated private static func withRootAccess<T: Sendable>(
        ctx: ScanContext, _ work: @Sendable @escaping () -> T) async -> T {
        await Task.detached(priority: .utility) {
            let started = ctx.allRoots.filter { $0.startAccessingSecurityScopedResource() }
            defer { for url in started { url.stopAccessingSecurityScopedResource() } }
            return work()
        }.value
    }

    // MARK: - Cache

    private func loadCache() {
        guard let data = UserDefaults.standard.data(forKey: "cache.results"),
              let cached = try? JSONDecoder().decode([String: ScanResult].self, from: data) else { return }
        for index in states.indices {
            states[index].result = cached[states[index].id.rawValue]
        }
    }

    private func saveCache() {
        var cached: [String: ScanResult] = [:]
        for state in states {
            if let result = state.result { cached[state.id.rawValue] = result }
        }
        if let data = try? JSONEncoder().encode(cached) {
            UserDefaults.standard.set(data, forKey: "cache.results")
        }
    }

    // MARK: - Background refresh

    private func scheduleTimer() {
        timer?.invalidate()
        timer = nil
        guard refreshIntervalHours > 0 else { return }
        let interval = TimeInterval(refreshIntervalHours) * 3600
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            Task { @MainActor in
                AppStateHolder.shared?.refreshAll()
            }
        }
    }
}

/// Weak global hook so the Timer closure doesn't retain AppState.
@MainActor
enum AppStateHolder {
    static weak var shared: AppState?
}
