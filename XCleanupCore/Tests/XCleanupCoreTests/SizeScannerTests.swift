import XCTest
@testable import XCleanupCore

final class SizeScannerTests: XCTestCase {
    var root: URL!

    override func setUpWithError() throws {
        root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("SizeScannerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    func write(_ bytes: Int, to relativePath: String) throws {
        let url = root.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(repeating: 0x41, count: bytes).write(to: url)
    }

    func testSumsNestedFiles() throws {
        try write(10_000, to: "a.bin")
        try write(20_000, to: "sub/b.bin")
        let size = SizeScanner.allocatedSize(of: root)
        XCTAssertGreaterThanOrEqual(size, 30_000)   // allocated >= logical
        XCTAssertLessThan(size, 30_000 + 2 * 1_048_576) // sane upper bound
    }

    func testDoesNotFollowSymlinks() throws {
        try write(1_000_000, to: "real/big.bin")
        let linkDir = root.appendingPathComponent("linked", isDirectory: true)
        try FileManager.default.createDirectory(at: linkDir, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(
            at: linkDir.appendingPathComponent("link"),
            withDestinationURL: root.appendingPathComponent("real/big.bin"))
        let size = SizeScanner.allocatedSize(of: linkDir)
        XCTAssertLessThan(size, 100_000)
    }

    func testMissingDirectoryIsZero() {
        let missing = root.appendingPathComponent("nope")
        XCTAssertEqual(SizeScanner.allocatedSize(of: missing), 0)
    }
}
