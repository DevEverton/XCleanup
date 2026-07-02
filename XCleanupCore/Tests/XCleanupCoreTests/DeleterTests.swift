import XCTest
@testable import XCleanupCore

final class DeleterTests: XCTestCase {
    var root: URL!

    override func setUpWithError() throws {
        root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("DeleterTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    func makeDir(_ name: String) throws -> URL {
        let url = root.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try Data(repeating: 1, count: 100).write(to: url.appendingPathComponent("f.bin"))
        return url
    }

    func testDeletesItemsInsideRoot() throws {
        let victim = try makeDir("victim")
        let item = ScanItem(name: "victim", url: victim, size: 100)
        let outcome = Deleter.delete(items: [item], allowedRoots: [root])
        XCTAssertEqual(outcome.deletedBytes, 100)
        XCTAssertTrue(outcome.failures.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: victim.path))
    }

    func testRefusesItemOutsideAllowedRoots() throws {
        let outside = try makeDir("outside")
        let item = ScanItem(name: "outside", url: outside, size: 100)
        let otherRoot = root.appendingPathComponent("victim-parent")
        let outcome = Deleter.delete(items: [item], allowedRoots: [otherRoot])
        XCTAssertEqual(outcome.deletedBytes, 0)
        XCTAssertEqual(outcome.failures.count, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: outside.path))
    }

    func testCollectsFailureForMissingItemAndContinues() throws {
        let real = try makeDir("real")
        let missing = root.appendingPathComponent("missing")
        let items = [
            ScanItem(name: "missing", url: missing, size: 50),
            ScanItem(name: "real", url: real, size: 100),
        ]
        let outcome = Deleter.delete(items: items, allowedRoots: [root])
        XCTAssertEqual(outcome.deletedBytes, 100)
        XCTAssertEqual(outcome.failures.count, 1)
        XCTAssertEqual(outcome.failures[0].itemName, "missing")
    }

    func testEraseContentsKeepsDirectory() throws {
        let device = try makeDir("device")
        try FileManager.default.createDirectory(at: device.appendingPathComponent("sub"), withIntermediateDirectories: true)
        let outcome = Deleter.eraseContents(of: device, allowedRoots: [root])
        XCTAssertTrue(outcome.failures.isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: device.path))
        let children = try FileManager.default.contentsOfDirectory(atPath: device.path)
        XCTAssertTrue(children.isEmpty)
    }
}
