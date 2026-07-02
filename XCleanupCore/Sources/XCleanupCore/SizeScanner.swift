import Foundation

public enum SizeScanner {
    /// Physical (allocated) size in bytes of all regular files under `url`.
    /// Symlinks are not followed. Returns 0 if the directory doesn't exist.
    public static func allocatedSize(of url: URL) -> Int64 {
        let keys: Set<URLResourceKey> = [
            .totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .isRegularFileKey, .isSymbolicLinkKey,
        ]
        guard let enumerator = FileManager.default.enumerator(
            at: url, includingPropertiesForKeys: Array(keys), options: []) else { return 0 }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: keys),
                  values.isSymbolicLink != true,          // resourceValues can resolve links
                  values.isRegularFile == true else { continue }
            total += Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
        }
        return total
    }
}
