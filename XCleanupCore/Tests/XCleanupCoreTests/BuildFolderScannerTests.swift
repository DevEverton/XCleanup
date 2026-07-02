import XCTest
@testable import XCleanupCore

final class BuildFolderScannerTests: XCTestCase {
    var root: URL!

    override func setUpWithError() throws {
        root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("BuildScannerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    func makePackage(_ relativePath: String, manifest: String = "Package.swift") throws {
        let pkg = root.appendingPathComponent(relativePath, isDirectory: true)
        try FileManager.default.createDirectory(
            at: pkg.appendingPathComponent(".build"), withIntermediateDirectories: true)
        try Data("// pkg".utf8).write(to: pkg.appendingPathComponent(manifest))
        try Data(repeating: 1, count: 5_000).write(to: pkg.appendingPathComponent(".build/artifact.o"))
    }

    func testFindsBuildDirsOnlyBesidePackageManifest() throws {
        try makePackage("repo/packages/PkgA")
        try makePackage("repo/PkgB", manifest: "Package.resolved")
        // .build with no manifest sibling — must be ignored
        let bare = root.appendingPathComponent("repo/notpkg/.build", isDirectory: true)
        try FileManager.default.createDirectory(at: bare, withIntermediateDirectories: true)

        let result = BuildFolderScanner.scan(roots: [root])
        XCTAssertEqual(Set(result.items.map(\.name)), ["PkgA", "PkgB"])
        let pkgA = result.items.first { $0.name == "PkgA" }!
        XCTAssertEqual(pkgA.detail, "repo/packages/PkgA")
        XCTAssertEqual(pkgA.url.lastPathComponent, ".build")
        XCTAssertGreaterThanOrEqual(pkgA.size, 5_000)
    }

    func testDoesNotDescendIntoFoundBuildDirs() throws {
        try makePackage("Pkg")
        // a nested package inside .build must NOT be reported
        let nested = root.appendingPathComponent("Pkg/.build/checkouts/Dep", isDirectory: true)
        try FileManager.default.createDirectory(
            at: nested.appendingPathComponent(".build"), withIntermediateDirectories: true)
        try Data("// dep".utf8).write(to: nested.appendingPathComponent("Package.swift"))

        let result = BuildFolderScanner.scan(roots: [root])
        XCTAssertEqual(result.items.count, 1)
    }

    func testSkipsNoiseDirsSymlinksAndDepthLimit() throws {
        try makePackage("node_modules/Pkg")          // inside skipped dir
        try makePackage("a/b/c/d/e/f/DeepPkg")       // beyond maxDepth 5
        try makePackage("real/Pkg")
        try FileManager.default.createSymbolicLink(
            at: root.appendingPathComponent("loop"), withDestinationURL: root)

        let result = BuildFolderScanner.scan(roots: [root], maxDepth: 5)
        XCTAssertEqual(result.items.map(\.name), ["Pkg"])
        XCTAssertEqual(result.items[0].detail, "real/Pkg")
    }
}
