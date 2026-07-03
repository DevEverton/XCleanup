<p align="center">
  <img src="docs/assets/icon-256.png" width="128" alt="XCleanup icon">
</p>

<h1 align="center">XCleanup</h1>

<p align="center">
  A tiny macOS menu bar app that shows how much disk space Xcode and Swift tooling
  are silently eating — and cleans it with one click.
</p>

<p align="center">
  <a href="https://github.com/DevEverton/XCleanup/actions/workflows/ci.yml"><img src="https://github.com/DevEverton/XCleanup/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <img src="https://img.shields.io/badge/macOS-14%2B-blue?logo=apple" alt="macOS 14+">
  <img src="https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white" alt="Swift 6">
  <img src="https://img.shields.io/badge/UI-SwiftUI-8A2BE2" alt="SwiftUI">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-green" alt="MIT license"></a>
</p>

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

Runs on **macOS 14 (Sonoma) or later**.

### Homebrew

*(available once the first release is tagged)*

```bash
brew install DevEverton/tap/xcleanup
```

### Direct download

Grab `XCleanup-<version>.zip` from [Releases](https://github.com/DevEverton/XCleanup/releases),
unzip, and move `XCleanup.app` to `/Applications`.

### Build from source (requires Xcode 26+)

```bash
git clone https://github.com/DevEverton/XCleanup.git
cd XCleanup
xcodebuild -project XCleanup.xcodeproj -scheme XCleanup -configuration Release build
```

Then copy `XCleanup.app` from the build products to `/Applications`.

## Releasing (maintainers)

`scripts/release.sh <version>` archives, exports with Developer ID, notarizes,
staples, zips, and prints the sha256 for the Homebrew cask
(`packaging/homebrew/xcleanup.rb` is the template for the tap).

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
