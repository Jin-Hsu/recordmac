#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p dist
build_dir=$(mktemp -d "$PWD/dist/build.XXXXXX")
app="$build_dir/轻录.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" "$build_dir/cache"
sdk=$(xcrun --sdk macosx --show-sdk-path)
xcrun swiftc -parse-as-library -swift-version 5 -target arm64-apple-macosx15.0 \
  -sdk "$sdk" -module-cache-path "$build_dir/cache" \
  Sources/QingLu/*.swift -o "$app/Contents/MacOS/QingLu" \
  -framework SwiftUI -framework AppKit -framework ScreenCaptureKit \
  -framework AVFoundation -framework CoreMedia -framework CoreGraphics
cp Resources/Info.plist "$app/Contents/Info.plist"
cp Resources/AppIcon.icns "$app/Contents/Resources/AppIcon.icns"
codesign --force --sign - --entitlements Resources/QingLu.entitlements "$app"
codesign --verify --deep --strict "$app"
plutil -lint "$app/Contents/Info.plist"
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)
stage="$build_dir/dmg"
mkdir -p "$stage"
ditto "$app" "$stage/轻录.app"
ln -s /Applications "$stage/Applications"
cp LICENSE "$stage/LICENSE.txt"
hdiutil create -volname "轻录 $version" -srcfolder "$stage" -ov -format UDZO "dist/QingLu-$version-arm64.dmg"
hdiutil verify "dist/QingLu-$version-arm64.dmg"
(cd dist && shasum -a 256 "QingLu-$version-arm64.dmg" > SHA256SUMS.txt)
printf 'Built: dist/QingLu-%s-arm64.dmg\n' "$version"
