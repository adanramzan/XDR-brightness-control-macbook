#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
app="$PWD/dist/XDR Brightness.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" build/XDRBrightness
sdk="$(xcrun --sdk macosx --show-sdk-path)"
version="$(cat VERSION)"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Invalid VERSION" >&2; exit 1; }
for arch in arm64 x86_64; do
  swiftc -swift-version 5 -O -module-cache-path "$PWD/build/SwiftModuleCache" -sdk "$sdk" -target "$arch-apple-macos12.0" -framework AppKit -framework MetalKit -framework QuartzCore -framework ApplicationServices XDRBrightness/BrightnessKeys.swift XDRBrightness/BoostPolicy.swift XDRBrightness/main.swift -o "build/XDRBrightness/$arch"
done
lipo -create build/XDRBrightness/arm64 build/XDRBrightness/x86_64 -output "$app/Contents/MacOS/XDRBrightness"
cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>XDRBrightness</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundleIdentifier</key><string>local.xdrbrightness.app</string>
<key>CFBundleName</key><string>XDR Brightness</string>
<key>CFBundleDisplayName</key><string>XDR Brightness</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$version</string>
<key>CFBundleVersion</key><string>2</string>
<key>LSMinimumSystemVersion</key><string>12.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
<key>NSSupportsAutomaticGraphicsSwitching</key><true/>
</dict></plist>
PLIST
cp -f XDRBrightness/AppIcon.icns XDRBrightness/LICENSE.txt XDRBrightness/NOTICE.txt XDRBrightness/MediaKeyTap-LICENSE.txt "$app/Contents/Resources/"
codesign --force --sign - --timestamp=none "$app"
codesign --verify --deep --strict "$app"
printf 'Built %s\n' "$app"
