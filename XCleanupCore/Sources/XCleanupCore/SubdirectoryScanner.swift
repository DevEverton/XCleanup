import Foundation

public enum SubdirectoryScanner {
    /// One ScanItem per immediate, non-hidden, non-symlink subdirectory of `root`.
    public static func scan(root: URL, nameTransform: (String) -> String = { $0 }) -> ScanResult {
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isSymbolicLinkKey]
        let children = (try? FileManager.default.contentsOfDirectory(
            at: root, includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles])) ?? []
        var items: [ScanItem] = []
        for child in children {
            guard let values = try? child.resourceValues(forKeys: keys),
                  values.isDirectory == true, values.isSymbolicLink != true else { continue }
            items.append(ScanItem(
                name: nameTransform(child.lastPathComponent),
                url: child,
                size: SizeScanner.allocatedSize(of: child)))
        }
        return ScanResult(items: items, scannedAt: Date())
    }

    /// "zilly-fmyifjuzquhmthggnjyzuzbrpwvf" -> "zilly".
    /// The DerivedData hash suffix is 28 lowercase alphanumerics after the last dash.
    public static func derivedDataDisplayName(_ folderName: String) -> String {
        guard let dash = folderName.lastIndex(of: "-") else { return folderName }
        let suffix = folderName[folderName.index(after: dash)...]
        guard suffix.count == 28,
              suffix.allSatisfy({ ($0.isLowercase && $0.isLetter) || $0.isNumber }) else {
            return folderName
        }
        return String(folderName[..<dash])
    }
}
