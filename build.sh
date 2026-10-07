#!/bin/bash
# Builds DevMonitor.app (release) and signs it ad-hoc.
set -euo pipefail
cd "$(dirname "$0")"

echo "▸ swift build (release)…"
ARCH_FLAGS=""
if [ "${UNIVERSAL:-0}" = "1" ]; then
    ARCH_FLAGS="--arch arm64 --arch x86_64"
    echo "  building universal binary (arm64 + x86_64)"
fi
swift build -c release $ARCH_FLAGS

# Universal cross-builds land in .build/apple/Products/Release
# instead of .build/release.
BIN=".build/release/DevMonitor"
if [ ! -f "$BIN" ] && [ -f ".build/apple/Products/Release/DevMonitor" ]; then
    BIN=".build/apple/Products/Release/DevMonitor"
fi

APP="DevMonitor.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN" "$APP/Contents/MacOS/DevMonitor"
if [ -f Assets/DevMonitor.icns ]; then
    cp Assets/DevMonitor.icns "$APP/Contents/Resources/DevMonitor.icns"
fi

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>              <string>DevMonitor</string>
    <key>CFBundleDisplayName</key>       <string>DevMonitor</string>
    <key>CFBundleExecutable</key>        <string>DevMonitor</string>
    <key>CFBundleIdentifier</key>        <string>dev.local.DevMonitor</string>
    <key>CFBundlePackageType</key>       <string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key>         <string>1</string>
    <key>CFBundleIconFile</key>        <string>DevMonitor</string>
    <key>LSMinimumSystemVersion</key>    <string>13.0</string>
    <key>LSUIElement</key>               <true/>
    <key>NSPrincipalClass</key>          <string>NSApplication</string>
    <key>NSHighResolutionCapable</key>   <true/>
</dict>
</plist>
PLIST

echo "▸ codesign (ad-hoc)…"
codesign --force --sign - "$APP"

echo "✓ Built $APP"
echo "  Run it with:  open \"$APP\""
