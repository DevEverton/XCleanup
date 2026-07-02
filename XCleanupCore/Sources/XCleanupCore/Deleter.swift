import Foundation

public enum Deleter {
    /// Deletes each item, refusing anything outside `allowedRoots`.
    /// Failures are collected per item; the batch never aborts early.
    public static func delete(items: [ScanItem], allowedRoots: [URL]) -> CleanOutcome {
        var deleted: Int64 = 0
        var failures: [CleanFailure] = []
        for item in items {
            guard isContained(item.url, in: allowedRoots) else {
                failures.append(CleanFailure(itemName: item.name, message: "Refused: outside granted folders"))
                continue
            }
            do {
                try FileManager.default.removeItem(at: item.url)
                deleted += item.size
            } catch {
                failures.append(CleanFailure(itemName: item.name, message: error.localizedDescription))
            }
        }
        return CleanOutcome(deletedBytes: deleted, failures: failures)
    }

    /// Deletes the immediate children of `url` but keeps `url` itself (simulator "Erase").
    public static func eraseContents(of url: URL, allowedRoots: [URL]) -> CleanOutcome {
        guard isContained(url, in: allowedRoots) else {
            return CleanOutcome(deletedBytes: 0, failures: [
                CleanFailure(itemName: url.lastPathComponent, message: "Refused: outside granted folders")
            ])
        }
        let children = (try? FileManager.default.contentsOfDirectory(
            at: url, includingPropertiesForKeys: nil, options: [])) ?? []
        let items = children.map { ScanItem(name: $0.lastPathComponent, url: $0, size: 0) }
        return delete(items: items, allowedRoots: allowedRoots)
    }

    static func isContained(_ url: URL, in roots: [URL]) -> Bool {
        let path = url.standardizedFileURL.resolvingSymlinksInPath().path
        return roots.contains { root in
            path.hasPrefix(root.standardizedFileURL.resolvingSymlinksInPath().path + "/")
        }
    }
}
