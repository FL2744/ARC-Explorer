#!/bin/bash
# Run on macOS with Xcode tools and a Developer ID Application identity.
set -euo pipefail
cd "$(dirname "$0")/.."
: "${SIGNING_IDENTITY:?Set SIGNING_IDENTITY to your Developer ID Application identity}"
: "${NOTARY_PROFILE:?Set NOTARY_PROFILE to your notarytool Keychain profile name}"
APP=release-work/ARC-Explorer.app
mkdir -p release-work downloads
bash build.sh "$APP"
codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$APP/Contents/Resources/ARCAskpass"
codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"
ditto -c -k --sequesterRsrc --keepParent "$APP" release-work/ARC-Explorer-for-notarization.zip
xcrun notarytool submit release-work/ARC-Explorer-for-notarization.zip --keychain-profile "$NOTARY_PROFILE" --wait --output-format json > release-work/notarization.json
python3 -c 'import json; r=json.load(open("release-work/notarization.json")); assert r.get("status")=="Accepted", "Notarization was not accepted"'
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"
spctl --assess --type execute --verbose=2 "$APP"
ditto -c -k --sequesterRsrc --keepParent "$APP" downloads/ARC-Explorer-v0.1-macOS-arm64.zip
shasum -a 256 downloads/ARC-Explorer-v0.1-macOS-arm64.zip
