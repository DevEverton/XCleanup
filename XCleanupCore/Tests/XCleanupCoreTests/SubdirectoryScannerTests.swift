import XCTest
@testable import XCleanupCore

final class SubdirectoryScannerTests: XCTestCase {
    var root: URL!

    override func setUpWithError() throws {
        root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("SubdirScannerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    func testListsSubdirectoriesWithSizes() throws {
        let a = root.appendingPathComponent("ProjA-abc", isDirectory: true)
        try FileManager.default.createDirectory(at: a, withIntermediateDirectories: true)
        try Data(repeating: 1, count: 50_000).write(to: a.appendingPathComponent("f.bin"))
        try Data(repeating: 1, count: 10).write(to: root.appendingPathComponent("loose-file.txt"))

        let result = SubdirectoryScanner.scan(root: root)
        XCTAssertEqual(result.items.count, 1)
        XCTAssertEqual(result.items[0].name, "ProjA-abc")
        XCTAssertGreaterThanOrEqual(result.items[0].size, 50_000)
    }

    func testSkipsSymlinkedDirectories() throws {
        let real = root.appendingPathComponent("real", isDirectory: true)
        try FileManager.default.createDirectory(at: real, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(
            at: root.appendingPathComponent("link"), withDestinationURL: real)
        let result = SubdirectoryScanner.scan(root: root)
        XCTAssertEqual(result.items.map(\.name), ["real"])
    }

    func testMissingRootYieldsEmptyResult() {
        let result = SubdirectoryScanner.scan(root: root.appendingPathComponent("nope"))
        XCTAssertTrue(result.items.isEmpty)
        XCTAssertEqual(result.totalSize, 0)
    }

    func testDerivedDataDisplayName() {
        XCTAssertEqual(
            SubdirectoryScanner.derivedDataDisplayName("zilly-fmyifjuzquhmthggnjyzuzbrpwvf"),
            "zilly")
        XCTAssertEqual(
            SubdirectoryScanner.derivedDataDisplayName("ModuleCache.noindex"),
            "ModuleCache.noindex")
        XCTAssertEqual(
            SubdirectoryScanner.derivedDataDisplayName("My-App-fmyifjuzquhmthggnjyzuzbrpwvf"),
            "My-App")
    }
}
