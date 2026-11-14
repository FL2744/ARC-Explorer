#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
APP="${1:-dist/ARC-Explorer.app}"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" .build
swiftc -swift-version 5 -target arm64-apple-macosx15.0 -module-cache-path .build/module-cache Sources/Icon.swift -o .build/icon-generator
mkdir -p .build/ARCExplorer.iconset
.build/icon-generator Resources/ARCExplorer.png
for size in 16 32 128 256 512; do
 sips -z "$size" "$size" Resources/ARCExplorer.png --out ".build/ARCExplorer.iconset/icon_${size}x${size}.png" >/dev/null
 double=$((size * 2))
 sips -z "$double" "$double" Resources/ARCExplorer.png --out ".build/ARCExplorer.iconset/icon_${size}x${size}@2x.png" >/dev/null
done
.build/icon-generator --pack .build/ARCExplorer.iconset Resources/ARCExplorer.icns
swift build --build-system native -c release --product ARC-Explorer
BIN_DIR=$(swift build --build-system native -c release --show-bin-path)
cp "$BIN_DIR/ARC-Explorer" "$APP/Contents/MacOS/ARC-Explorer"
for bundle in "$BIN_DIR"/*.bundle; do
 if [ -d "$bundle" ]; then ditto "$bundle" "$APP/Contents/Resources/$(basename "$bundle")"; fi
done
cp Vendor/SwiftTerm/LICENSE "$APP/Contents/Resources/SwiftTerm-LICENSE.txt"
swiftc -swift-version 5 -O -target arm64-apple-macosx15.0 -module-cache-path .build/module-cache Sources/Askpass.swift -o "$APP/Contents/Resources/ARCAskpass"
cp Resources/remote_agent.py "$APP/Contents/Resources/"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>ARC-Explorer</string>
<key>CFBundleIdentifier</key><string>edu.vt.arc-explorer</string>
<key>CFBundleName</key><string>ARC-Explorer</string>
<key>CFBundleDisplayName</key><string>ARC-Explorer</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleVersion</key><string>4</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSMinimumSystemVersion</key><string>15.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSPrincipalClass</key><string>NSApplication</string>
<key>NSAppTransportSecurity</key><dict><key>NSAllowsLocalNetworking</key><true/></dict>
<key>NSHumanReadableCopyright</key><string>William Taggart · ARC-Explorer</string>
</dict></plist>
PLIST
if [ -f Resources/ARCExplorer.icns ]; then cp Resources/ARCExplorer.icns "$APP/Contents/Resources/"; /usr/libexec/PlistBuddy -c 'Add :CFBundleIconFile string ARCExplorer' "$APP/Contents/Info.plist"; fi
codesign --force --sign - "$APP/Contents/Resources/ARCAskpass"
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"
echo "Built $APP"
