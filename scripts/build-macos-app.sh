#!/bin/zsh
set -eu
cd -- "${0:A:h:h}"
app="${PWD}/dist/Lightmail.app"
mkdir -p "$app/Contents/MacOS"
mkdir -p "$app/Contents/Resources" work/macos-icon
swift macos/GenerateIcon.swift work/macos-icon/Lightmail.iconset
iconutil -c icns work/macos-icon/Lightmail.iconset -o "$app/Contents/Resources/Lightmail.icns"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>com.lightmail.local</string>
  <key>CFBundleName</key><string>Lightmail</string>
  <key>CFBundleDisplayName</key><string>Lightmail</string>
  <key>CFBundleExecutable</key><string>Lightmail</string>
  <key>CFBundleIconFile</key><string>Lightmail</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>2.0</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSAppTransportSecurity</key><dict><key>NSAllowsLocalNetworking</key><true/></dict>
</dict></plist>
PLIST
swiftc -swift-version 5 -O -framework AppKit -framework WebKit macos/Lightmail.swift -o "$app/Contents/MacOS/Lightmail"
chmod 755 "$app/Contents/MacOS/Lightmail"
print "Built $app"
