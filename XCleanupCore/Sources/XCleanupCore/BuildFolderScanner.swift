import Foundation

public enum BuildFolderScanner {
    public static let skippedDirectoryNames: Set<String> = [
        ".git", "node_modules", "Pods", "DerivedData", ".build", ".swiftpm",
    ]

    /// Finds SwiftPM .build directories under the given roots.
    /// A .build dir is eligible only when Package.swift or Package.resolved
    /// sits beside it. Never descends into found .build dirs, skipped names,
    /// or symlinks. Depth is limited to `maxDepth` levels below each root.
    public static func scan(roots: [URL], maxDepth: Int = 5) -> ScanResult {
        var items: [ScanItem] = []
        for root in roots {
            walk(root, root: root, depth: 0, maxDepth: maxDepth, into: &items)
        }
        return ScanResult(items: items, scannedAt: Date())
    }

    private static func walk(_ dir: URL, root: URL, depth: Int, maxDepth: Int, into items: inout [ScanItem]) {
        guard depth <= maxDepth else { return }
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isSymbolicLinkKey]
        let children = (try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: Array(keys), options: [])) ?? []
        for child in children {
            guard let values = try? child.resourceValues(forKeys: keys),
                  values.isDirectory == true, values.isSymbolicLink != true else { continue }
            let name = child.lastPathComponent
            if name == ".build" {
                if isSwiftPackageDirectory(dir) {
                    items.append(ScanItem(
                        name: dir.lastPathComponent,
                        detail: relativePath(of: dir, under: root),
                        url: child,
                        size: SizeScanner.allocatedSize(of: child)))
                }
                continue // never descend into .build
            }
            if skippedDirectoryNames.contains(name) { continue }
            walk(child, root: root, depth: depth + 1, maxDepth: maxDepth, into: &items)
        }
    }

    static func isSwiftPackageDirectory(_ dir: URL) -> Bool {
        let fm = FileManager.default
        return fm.fileExists(atPath: dir.appendingPathComponent("Package.swift").path)
            || fm.fileExists(atPath: dir.appendingPathComponent("Package.resolved").path)
    }

    static func relativePath(of url: URL, under root: URL) -> String {
        let rootPath = root.standardizedFileURL.path + "/"
        let path = url.standardizedFileURL.path
        return path.hasPrefix(rootPath) ? String(path.dropFirst(rootPath.count)) : path
    }
}
