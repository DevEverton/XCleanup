import Foundation

public struct ScanItem: Codable, Hashable, Identifiable, Sendable {
    public let name: String
    public let detail: String?
    public let url: URL
    public let size: Int64
    public let isStale: Bool

    public var id: String { url.path }

    public init(name: String, detail: String? = nil, url: URL, size: Int64, isStale: Bool = false) {
        self.name = name
        self.detail = detail
        self.url = url
        self.size = size
        self.isStale = isStale
    }
}

public struct ScanResult: Codable, Hashable, Sendable {
    public let totalSize: Int64
    public let items: [ScanItem]
    public let scannedAt: Date

    public init(items: [ScanItem], scannedAt: Date) {
        self.items = items.sorted { $0.size > $1.size }
        self.totalSize = items.reduce(0) { $0 + $1.size }
        self.scannedAt = scannedAt
    }
}

public struct CleanFailure: Codable, Hashable, Sendable {
    public let itemName: String
    public let message: String

    public init(itemName: String, message: String) {
        self.itemName = itemName
        self.message = message
    }
}

public struct CleanOutcome: Codable, Hashable, Sendable {
    public let deletedBytes: Int64
    public let failures: [CleanFailure]

    public init(deletedBytes: Int64, failures: [CleanFailure]) {
        self.deletedBytes = deletedBytes
        self.failures = failures
    }
}
