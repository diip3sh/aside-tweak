#!/bin/bash
# Builds "Aside Tweak.app" next to this script. The app must stay in this folder.
set -euo pipefail
cd "$(dirname "$0")"

APP="Aside Tweak.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"

swiftc -O -swift-version 6 -parse-as-library -target arm64-apple-macos14 \
  app/*.swift -o "$APP/Contents/MacOS/Aside Tweak"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>Aside Tweak</string>
  <key>CFBundleIdentifier</key><string>local.aside-tweak.app</string>
  <key>CFBundleName</key><string>Aside Tweak</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSAppTransportSecurity</key><dict><key>NSAllowsLocalNetworking</key><true/></dict>
</dict></plist>
PLIST

# Screenshots of Aside for each setting, taken in a separate test profile.
mkdir -p "$APP/Contents/Resources"
cp -R previews "$APP/Contents/Resources/previews"

codesign --force --sign - "$APP"
echo "Built $APP"
