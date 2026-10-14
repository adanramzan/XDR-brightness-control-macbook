#!/bin/bash
# Regenerates XDRBrightness/AppIcon.icns (committed; build.sh only copies it).
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
rm -rf build/AppIcon.iconset
swiftc -module-cache-path "$PWD/build/SwiftModuleCache" scripts/make-icon.swift -o build/make-icon
build/make-icon build/AppIcon.iconset
iconutil -c icns build/AppIcon.iconset -o XDRBrightness/AppIcon.icns
printf 'Wrote XDRBrightness/AppIcon.icns\n'
