// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "XCleanupCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "XCleanupCore", targets: ["XCleanupCore"])
    ],
    targets: [
        .target(name: "XCleanupCore"),
        .testTarget(name: "XCleanupCoreTests", dependencies: ["XCleanupCore"]),
    ]
)
