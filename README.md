# XCleanup

A tiny macOS menu bar app that shows you how much disk space Xcode and Swift
tooling are silently eating — and cleans it with one click.

Build artifacts accumulate fast: DerivedData, simulator devices, per-package
SwiftPM `.build` folders scattered through your repos. They can quietly grow
to hundreds of gigabytes. XCleanup keeps them visible and one confirmation
away from gone.

## What it cleans

| Category | Location | Granularity |
|---|---|---|
| DerivedData | `~/Library/Developer/Xcode/DerivedData` | All, or per project |
| XcodeBuildMCP | `~/Library/Developer/XcodeBuildMCP/workspaces` | All |
| iOS DeviceSupport | `~/Library/Developer/Xcode/iOS DeviceSupport` | Per OS version |
| Simulators | `~/Library/Developer/CoreSimulator/Devices` | Delete or erase per device; one-click delete of unavailable devices |
| Package Builds | Your code folders (home folder by default) | Per package — finds every SwiftPM `.build` directory next to a `Package.swift`/`Package.resolved` |

## Safety

- Every deletion is behind a confirmation dialog.
- `.build` folders are only eligible when a Swift package manifest sits beside
  them; symlinks are never followed; deletions are refused outside the
  configured scan roots.
- Everything XCleanup deletes is regenerable build output — the cost of a
  mistake is a cold rebuild, not lost work.

## Install

Build from source (requires Xcode 26+):

```bash
git clone <this repo>
cd XCleanup
xcodebuild -project XCleanup.xcodeproj -scheme XCleanup -configuration Release build
```

Then copy `XCleanup.app` from the build products to `/Applications`.

## Notes

- The app lives in the menu bar (no Dock icon); a full window with sortable
  per-item tables is one click away from the panel footer. Enable "Launch at
  login" in its Settings.
- Sizes shown are physical (allocated) bytes, so APFS clones aren't
  double-counted.
- macOS will ask once for permission when the scanner first touches protected
  folders like Desktop or Documents.
- Simulator deletion works at the file level (no `simctl`); Xcode's device
  list catches up when the CoreSimulator service restarts.

## Development

Core logic lives in the `XCleanupCore` local Swift package (scanning, parsing,
deletion — fully unit tested); the app target is a thin SwiftUI layer.

```bash
cd XCleanupCore && swift test
```

## License

[MIT](LICENSE)
