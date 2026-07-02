import Foundation
import XCleanupCore

nonisolated struct ScanContext: Sendable {
    let developerRoot: URL
    let projectRoots: [URL]
    var allRoots: [URL] { [developerRoot] + projectRoots }
}

enum CategoryID: String, CaseIterable, Codable, Sendable {
    case derivedData, xcodeBuildMCP, deviceSupport, simulators, spmBuild
}

struct CleanupCategory: Identifiable, Sendable {
    let id: CategoryID
    let title: String
    let systemImage: String
    let scan: @Sendable (ScanContext) -> ScanResult
}

let allCategories: [CleanupCategory] = [
    CleanupCategory(id: .derivedData, title: "DerivedData", systemImage: "hammer") { ctx in
        SubdirectoryScanner.scan(
            root: ctx.developerRoot.appendingPathComponent("Xcode/DerivedData", isDirectory: true),
            nameTransform: SubdirectoryScanner.derivedDataDisplayName)
    },
    CleanupCategory(id: .xcodeBuildMCP, title: "XcodeBuildMCP", systemImage: "wrench.and.screwdriver") { ctx in
        SubdirectoryScanner.scan(
            root: ctx.developerRoot.appendingPathComponent("XcodeBuildMCP/workspaces", isDirectory: true))
    },
    CleanupCategory(id: .deviceSupport, title: "iOS DeviceSupport", systemImage: "iphone") { ctx in
        SubdirectoryScanner.scan(
            root: ctx.developerRoot.appendingPathComponent("Xcode/iOS DeviceSupport", isDirectory: true))
    },
    CleanupCategory(id: .simulators, title: "Simulators", systemImage: "iphone.gen3") { ctx in
        let catalog = SimulatorInventory.installedRuntimes(
            imagesPlistURL: URL(fileURLWithPath: "/Library/Developer/CoreSimulator/Images/images.plist"))
        let devices = SimulatorInventory.devices(
            devicesRoot: ctx.developerRoot.appendingPathComponent("CoreSimulator/Devices", isDirectory: true),
            installedRuntimes: catalog)
        return ScanResult(
            items: devices.map { device in
                ScanItem(
                    name: device.name,
                    detail: device.runtimeDisplayName,
                    url: device.url,
                    size: device.size,
                    isStale: device.isAvailable == false)
            },
            scannedAt: Date())
    },
    CleanupCategory(id: .spmBuild, title: "Package Builds", systemImage: "shippingbox") { ctx in
        BuildFolderScanner.scan(roots: ctx.projectRoots)
    },
]
