import Foundation

public struct SimulatorDevice: Codable, Hashable, Sendable {
    public let udid: String
    public let name: String
    public let runtimeIdentifier: String
    public let url: URL
    public let size: Int64
    /// nil = runtime catalog unavailable, availability unknown.
    public let isAvailable: Bool?

    public var runtimeDisplayName: String { Self.displayName(forRuntime: runtimeIdentifier) }
    public var dataURL: URL { url.appendingPathComponent("data", isDirectory: true) }

    /// "com.apple.CoreSimulator.SimRuntime.iOS-26-0" -> "iOS 26.0"
    public static func displayName(forRuntime identifier: String) -> String {
        let prefix = "com.apple.CoreSimulator.SimRuntime."
        guard identifier.hasPrefix(prefix) else { return identifier }
        let rest = identifier.dropFirst(prefix.count)
        let parts = rest.split(separator: "-")
        guard parts.count >= 2 else { return String(rest) }
        return parts[0] + " " + parts.dropFirst().joined(separator: ".")
    }
}

public enum SimulatorInventory {
    /// Lists devices under ~/Library/Developer/CoreSimulator/Devices by reading
    /// each folder's device.plist. Folders without a parseable plist are skipped.
    public static func devices(devicesRoot: URL, installedRuntimes: Set<String>?) -> [SimulatorDevice] {
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isSymbolicLinkKey]
        let children = (try? FileManager.default.contentsOfDirectory(
            at: devicesRoot, includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles])) ?? []
        var devices: [SimulatorDevice] = []
        for child in children {
            guard let values = try? child.resourceValues(forKeys: keys),
                  values.isDirectory == true, values.isSymbolicLink != true,
                  let data = try? Data(contentsOf: child.appendingPathComponent("device.plist")),
                  let parsed = parseDevicePlist(data) else { continue }
            devices.append(SimulatorDevice(
                udid: parsed.udid,
                name: parsed.name,
                runtimeIdentifier: parsed.runtime,
                url: child,
                size: SizeScanner.allocatedSize(of: child),
                isAvailable: installedRuntimes.map { $0.contains(parsed.runtime) }))
        }
        return devices
    }

    static func parseDevicePlist(_ data: Data) -> (udid: String, name: String, runtime: String)? {
        guard let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let udid = dict["UDID"] as? String,
              let name = dict["name"] as? String,
              let runtime = dict["runtime"] as? String else { return nil }
        return (udid, name, runtime)
    }

    /// Parses /Library/Developer/CoreSimulator/Images/images.plist for installed
    /// runtime identifiers. Returns nil when unreadable or the shape is unexpected,
    /// in which case availability is treated as unknown everywhere.
    public static func installedRuntimes(imagesPlistURL: URL) -> Set<String>? {
        guard let data = try? Data(contentsOf: imagesPlistURL),
              let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let images = dict["images"] as? [[String: Any]] else { return nil }
        let identifiers = images.compactMap { image -> String? in
            (image["runtimeInfo"] as? [String: Any])?["identifier"] as? String
        }
        return identifiers.isEmpty ? nil : Set(identifiers)
    }
}
