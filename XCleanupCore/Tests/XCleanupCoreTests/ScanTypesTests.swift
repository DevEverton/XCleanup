import XCTest
@testable import XCleanupCore

final class ScanTypesTests: XCTestCase {
    func testScanResultSortsAndSums() {
        let a = ScanItem(name: "a", url: URL(fileURLWithPath: "/tmp/a"), size: 10)
        let b = ScanItem(name: "b", url: URL(fileURLWithPath: "/tmp/b"), size: 30)
        let result = ScanResult(items: [a, b], scannedAt: Date())
        XCTAssertEqual(result.totalSize, 40)
        XCTAssertEqual(result.items.map(\.name), ["b", "a"])
    }

    func testScanResultCodableRoundTrip() throws {
        let item = ScanItem(name: "x", detail: "d", url: URL(fileURLWithPath: "/tmp/x"), size: 5, isStale: true)
        let result = ScanResult(items: [item], scannedAt: Date(timeIntervalSince1970: 1000))
        let data = try JSONEncoder().encode(result)
        let decoded = try JSONDecoder().decode(ScanResult.self, from: data)
        XCTAssertEqual(decoded, result)
        XCTAssertEqual(decoded.items[0].id, "/tmp/x")
        XCTAssertTrue(decoded.items[0].isStale)
    }
}
