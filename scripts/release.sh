#!/bin/bash
# Builds, signs, notarizes and packages a release.
#
# Usage: scripts/release.sh <version>            e.g. scripts/release.sh 1.0.0
#
# One-time prerequisites:
#   1. A "Developer ID Application" certificate in your keychain
#      (paid Apple Developer account; adjust teamID in ExportOptions.plist
#      if you switch teams).
#   2. Notarization credentials stored once:
#      xcrun notarytool store-credentials xcleanup
set -euo pipefail

VERSION="${1:?usage: scripts/release.sh <version>}"
cd "$(dirname "$0")/.."

rm -rf build
xcodebuild -project XCleanup.xcodeproj -scheme XCleanup -configuration Release \
  archive -archivePath build/XCleanup.xcarchive

xcodebuild -exportArchive -archivePath build/XCleanup.xcarchive \
  -exportOptionsPlist ExportOptions.plist -exportPath build/export

APP="build/export/XCleanup.app"
ZIP="build/XCleanup-$VERSION.zip"

ditto -c -k --keepParent "$APP" "$ZIP"
xcrun notarytool submit "$ZIP" --keychain-profile xcleanup --wait
xcrun stapler staple "$APP"
ditto -c -k --keepParent "$APP" "$ZIP"   # re-zip the stapled app

echo
shasum -a 256 "$ZIP"
echo
echo "Next steps:"
echo "  gh release create v$VERSION \"$ZIP\" --title \"XCleanup $VERSION\""
echo "  Update version + sha256 in your tap's Casks/xcleanup.rb"
