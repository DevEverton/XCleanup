import XCTest
@testable import XCleanupCore

final class SimulatorInventoryTests: XCTestCase {
    var devicesRoot: URL!

    override func setUpWithError() throws {
        devicesRoot = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("SimInventoryTests-\(UUID().uuidString)/Devices", isDirectory: true)
        try FileManager.default.createDirectory(at: devicesRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: devicesRoot.deletingLastPathComponent())
    }

    func makeDevice(udid: String, name: String, runtime: String) throws {
        let dir = devicesRoot.appendingPathComponent(udid, isDirectory: true)
        try FileManager.default.createDirectory(
            at: dir.appendingPathComponent("data"), withIntermediateDirectories: true)
        let plist: [String: Any] = [
            "UDID": udid, "name": name, "runtime": runtime,
            "deviceType": "com.apple.CoreSimulator.SimDeviceType.iPhone-16",
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .binary, options: 0)
        try data.write(to: dir.appendingPathComponent("device.plist"))
        try Data(repeating: 1, count: 10_000).write(to: dir.appendingPathComponent("data/blob.bin"))
    }

    func testParsesDevicesAndAvailability() throws {
        try makeDevice(udid: "AAAA-1111", name: "iPhone 16", runtime: "com.apple.CoreSimulator.SimRuntime.iOS-26-0")
        try makeDevice(udid: "BBBB-2222", name: "Old iPhone", runtime: "com.apple.CoreSimulator.SimRuntime.iOS-17-0")

        let devices = SimulatorInventory.devices(
            devicesRoot: devicesRoot,
            installedRuntimes: ["com.apple.CoreSimulator.SimRuntime.iOS-26-0"])
            .sorted { $0.udid < $1.udid }

        XCTAssertEqual(devices.count, 2)
        XCTAssertEqual(devices[0].name, "iPhone 16")
        XCTAssertEqual(devices[0].isAvailable, true)
        XCTAssertEqual(devices[1].isAvailable, false)
        XCTAssertGreaterThanOrEqual(devices[0].size, 10_000)
        XCTAssertEqual(devices[0].dataURL.lastPathComponent, "data")
    }

    func testUnknownCatalogMeansNilAvailability() throws {
        try makeDevice(udid: "CCCC-3333", name: "X", runtime: "com.apple.CoreSimulator.SimRuntime.iOS-26-0")
        let devices = SimulatorInventory.devices(devicesRoot: devicesRoot, installedRuntimes: nil)
        XCTAssertEqual(devices.count, 1)
        XCTAssertNil(devices[0].isAvailable)
    }

    func testSkipsFoldersWithoutDevicePlist() throws {
        try FileManager.default.createDirectory(
            at: devicesRoot.appendingPathComponent("not-a-device"), withIntermediateDirectories: true)
        XCTAssertTrue(SimulatorInventory.devices(devicesRoot: devicesRoot, installedRuntimes: nil).isEmpty)
    }

    func testRuntimeDisplayName() {
        XCTAssertEqual(
            SimulatorDevice.displayName(forRuntime: "com.apple.CoreSimulator.SimRuntime.iOS-26-0"),
            "iOS 26.0")
        XCTAssertEqual(
            SimulatorDevice.displayName(forRuntime: "com.apple.CoreSimulator.SimRuntime.watchOS-11-2"),
            "watchOS 11.2")
        XCTAssertEqual(SimulatorDevice.displayName(forRuntime: "weird"), "weird")
    }

    func testInstalledRuntimesParsesImagesPlist() throws {
        let plist: [String: Any] = ["images": [
            ["runtimeInfo": ["identifier": "com.apple.CoreSimulator.SimRuntime.iOS-26-0"]],
            ["runtimeInfo": ["identifier": "com.apple.CoreSimulator.SimRuntime.iOS-18-4"]],
        ]]
        let url = devicesRoot.appendingPathComponent("images.plist")
        try PropertyListSerialization.data(fromPropertyList: plist, format: .binary, options: 0).write(to: url)

        let runtimes = SimulatorInventory.installedRuntimes(imagesPlistURL: url)
        XCTAssertEqual(runtimes, [
            "com.apple.CoreSimulator.SimRuntime.iOS-26-0",
            "com.apple.CoreSimulator.SimRuntime.iOS-18-4",
        ])
    }

    func testInstalledRuntimesNilWhenMissingOrMalformed() throws {
        XCTAssertNil(SimulatorInventory.installedRuntimes(
            imagesPlistURL: devicesRoot.appendingPathComponent("nope.plist")))
        let bad = devicesRoot.appendingPathComponent("bad.plist")
        try PropertyListSerialization.data(fromPropertyList: ["x": 1], format: .binary, options: 0).write(to: bad)
        XCTAssertNil(SimulatorInventory.installedRuntimes(imagesPlistURL: bad))
    }
}
