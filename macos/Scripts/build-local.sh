#!/bin/bash
# Build with installed Command Line Tools, independently of the Xcode GUI.
set -euo pipefail
cd "$(dirname "$0")/.."
TASK_DEVELOPER_DIR=/Library/Developer/CommandLineTools
TASK_APP_DIR="$PWD/build/local/Liquidity Edge.app"
mkdir -p "$TASK_APP_DIR/Contents/MacOS" "$TASK_APP_DIR/Contents/Resources"
TASK_SOURCES=()
while IFS= read -r source; do TASK_SOURCES+=("$source"); done < <(find LiquidityEdge -name '*.swift' -print | sort)
DEVELOPER_DIR="$TASK_DEVELOPER_DIR" "$TASK_DEVELOPER_DIR/usr/bin/swiftc" -swift-version 5 -target "$(uname -m)-apple-macosx14.0" -sdk "$TASK_DEVELOPER_DIR/SDKs/MacOSX.sdk" -plugin-path /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/lib/swift/host/plugins -parse-as-library -O -whole-module-optimization -g -enable-testing -module-name LiquidityEdge -emit-executable -emit-module -emit-module-path build/local/LiquidityEdge.swiftmodule "${TASK_SOURCES[@]}" -o "$TASK_APP_DIR/Contents/MacOS/Liquidity Edge"
cat > "$TASK_APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>CFBundleExecutable</key><string>Liquidity Edge</string><key>CFBundleIdentifier</key><string>com.liquidityedge.journal</string><key>CFBundleName</key><string>LIQUIDITY EDGE</string><key>CFBundlePackageType</key><string>APPL</string><key>CFBundleShortVersionString</key><string>6.0.0</string><key>CFBundleVersion</key><string>6</string><key>LSMinimumSystemVersion</key><string>14.0</string><key>NSHighResolutionCapable</key><true/></dict></plist>
PLIST
TASK_ICONSET="$PWD/build/local/AppIcon.iconset"
mkdir -p "$TASK_ICONSET"
for icon in LiquidityEdge/Resources/Assets.xcassets/AppIcon.appiconset/*.png; do
    filename="$(basename "$icon")"
    cp "$icon" "$TASK_ICONSET/${filename/@1x/}"
done
/usr/bin/iconutil -c icns "$TASK_ICONSET" -o "$TASK_APP_DIR/Contents/Resources/AppIcon.icns"
/usr/libexec/PlistBuddy -c 'Add :CFBundleIconFile string AppIcon' "$TASK_APP_DIR/Contents/Info.plist"
codesign --force --sign - "$TASK_APP_DIR"
echo "Built: $TASK_APP_DIR"
