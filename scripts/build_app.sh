#!/bin/bash
# build_app.sh
# Builds DontSleep.app bundle from the Swift Package Manager binary.
#
# Usage:
#   ./scripts/build_app.sh                # build in-place (dist/DontSleep.app)
#   ./scripts/build_app.sh --install      # also copy into ~/Applications
#
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="DontSleep"
APP_VERSION="0.1.0"
APP_BUILD="1"
BUNDLE_ID="com.haru.dontsleep"              # change for production
MIN_MACOS="13.0"

BUILD_DIR=".build/release"
DIST_DIR="dist"
APP_BUNDLE="$DIST_DIR/${APP_NAME}.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RES_DIR="$CONTENTS/Resources"

echo ">>> swift build (release)"
swift build -c release

echo ">>> clean old bundle"
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR" "$RES_DIR"

echo ">>> copy executable"
cp "$BUILD_DIR/$APP_NAME" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"

echo ">>> write Info.plist"
cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>ja</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${APP_VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${APP_BUILD}</string>
    <key>LSMinimumSystemVersion</key>
    <string>${MIN_MACOS}</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>© 2026 haru. All rights reserved.</string>
    <key>NSSupportsAutomaticTermination</key>
    <false/>
    <key>NSSupportsSuddenTermination</key>
    <false/>
</dict>
</plist>
PLIST

echo ">>> write PkgInfo"
printf "APPL????" > "$CONTENTS/PkgInfo"

# Optional install step
if [[ "${1:-}" == "--install" ]]; then
    TARGET="$HOME/Applications/${APP_NAME}.app"
    mkdir -p "$HOME/Applications"
    rm -rf "$TARGET"
    cp -R "$APP_BUNDLE" "$TARGET"
    echo ">>> installed: $TARGET"
fi

echo ""
echo "✅ done: $APP_BUNDLE"
echo ""
echo "to run:"
echo "  open \"$APP_BUNDLE\""
echo ""
echo "to install into ~/Applications:"
echo "  ./scripts/build_app.sh --install"
