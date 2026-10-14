#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
version="$(cat VERSION)"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Invalid VERSION" >&2; exit 1; }
app="dist/XDR Brightness.app"
[[ -d "$app" ]] || { echo 'Build the app first: bash XDRBrightness/build.sh' >&2; exit 1; }
built_version="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app/Contents/Info.plist")"
[[ "$built_version" == "$version" ]] || { echo 'App version differs from VERSION; rebuild first.' >&2; exit 1; }
git rev-parse --verify HEAD >/dev/null
[[ -z "$(git status --porcelain --untracked-files=normal)" ]] || { echo 'Commit source changes before packaging so the source archive matches the app.' >&2; exit 1; }
codesign --verify --deep --strict "$app"
stage="$(mktemp -d "$PWD/build/dmg-stage.XXXXXX")"
dmg="XDR-Brightness-$version-universal.dmg"
archive="XDR-Brightness-$version-source.tar.gz"
git archive --format=tar.gz HEAD -o "dist/$archive"
ditto "$app" "$stage/XDR Brightness.app"
ln -s /Applications "$stage/Applications"
mkdir "$stage/Source"
tar -xzf "dist/$archive" -C "$stage/Source"
cp LICENSE NOTICE "$stage/"
hdiutil create -volname 'XDR Brightness' -srcfolder "$stage" -ov -format UDZO "dist/$dmg"
hdiutil verify "dist/$dmg"
(cd dist && shasum -a 256 "$dmg" "$archive" > SHA256SUMS.txt)
printf 'Release assets: dist/%s, dist/%s, dist/SHA256SUMS.txt\n' "$dmg" "$archive"
