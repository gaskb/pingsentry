#!/bin/bash
set -euo pipefail

APP_NAME="PingSentry"
BUNDLE_ID="net.gaskb.pingsentry"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build/release"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"

VERSION=$(grep -oE '"[0-9]+\.[0-9]+\.[0-9]+"' "$ROOT_DIR/Sources/PingSentry/Version.swift" | tr -d '"')

echo "Building $APP_NAME $VERSION (release)..."
swift build -c release --package-path "$ROOT_DIR"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>© Gas</string>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP_BUNDLE"

echo "Built: $APP_BUNDLE"
echo
echo "Avvio automatico al login e notifiche funzionano solo su un'app impacchettata con bundle ID"
echo "(swift run non basta). Per un test affidabile, copiala in /Applications:"
echo "  cp -R \"$APP_BUNDLE\" /Applications/"
echo
echo "Essendo firmata ad-hoc (non notarizzata), al primo avvio da /Applications macOS potrebbe"
echo "avvisare che l'app non è verificata: click destro > Apri per confermare una volta sola."
