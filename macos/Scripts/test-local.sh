#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
TASK_TOOLCHAIN=/Library/Developer/CommandLineTools
TASK_FRAMEWORKS=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/Library/Frameworks
TASK_TEST_LIB=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/lib
TASK_TEST_DIR="$PWD/build/testing"
TASK_BUNDLE="$TASK_TEST_DIR/LiquidityEdgeTests.xctest"
mkdir -p "$TASK_BUNDLE/Contents/MacOS"
TASK_CORE=(LiquidityEdge/Models/*.swift LiquidityEdge/Utilities/*.swift LiquidityEdge/Services/*.swift LiquidityEdge/ViewModels/*.swift LiquidityEdge/Components/*.swift LiquidityEdge/Charts/*.swift LiquidityEdge/Extensions/*.swift LiquidityEdge/Views/*.swift)
DEVELOPER_DIR="$TASK_TOOLCHAIN" "$TASK_TOOLCHAIN/usr/bin/swiftc" -swift-version 5 -target arm64-apple-macosx14.0 -sdk "$TASK_TOOLCHAIN/SDKs/MacOSX.sdk" -plugin-path /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/lib/swift/host/plugins -parse-as-library -g -enable-testing -module-name LiquidityEdge -emit-module -emit-module-path "$TASK_TEST_DIR/LiquidityEdge.swiftmodule" -emit-library "${TASK_CORE[@]}" -o "$TASK_TEST_DIR/libLiquidityEdge.dylib" -Xlinker -install_name -Xlinker @rpath/libLiquidityEdge.dylib
DEVELOPER_DIR="$TASK_TOOLCHAIN" "$TASK_TOOLCHAIN/usr/bin/swiftc" -swift-version 5 -target arm64-apple-macosx14.0 -sdk "$TASK_TOOLCHAIN/SDKs/MacOSX.sdk" -parse-as-library -g -module-name LiquidityEdgeTests -I "$TASK_TEST_DIR" -L "$TASK_TEST_DIR" -lLiquidityEdge -I "$TASK_TEST_LIB" -L "$TASK_TEST_LIB" -lXCTestSwiftSupport -Xlinker -rpath -Xlinker "$TASK_TEST_LIB" -F "$TASK_FRAMEWORKS" -framework XCTest -Xlinker -rpath -Xlinker "$TASK_FRAMEWORKS" -Xlinker -rpath -Xlinker "$TASK_TEST_DIR" -emit-library Tests/*.swift -o "$TASK_BUNDLE/Contents/MacOS/LiquidityEdgeTests"
cat > "$TASK_BUNDLE/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict><key>CFBundleExecutable</key><string>LiquidityEdgeTests</string><key>CFBundleIdentifier</key><string>com.liquidityedge.tests</string><key>CFBundlePackageType</key><string>BNDL</string></dict></plist>
PLIST
/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/Library/Xcode/Agents/xctest "$TASK_BUNDLE"
