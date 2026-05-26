#!/bin/bash
set -e

APP_NAME="SpotifyPinyinLyric"
APP_BUNDLE="${APP_NAME}.app"
RELEASE_BINARY=".build/release/${APP_NAME}"
ZIP_NAME="${APP_NAME}.zip"

echo "Building release binary..."
swift build -c release

echo "Creating .app bundle..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp "${RELEASE_BINARY}"       "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
cp Info.plist                "${APP_BUNDLE}/Contents/Info.plist"
cp AppIcon.icns              "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"

echo "Zipping..."
rm -f "${ZIP_NAME}"
zip -r "${ZIP_NAME}" "${APP_BUNDLE}"

echo ""
echo "Done! Share: $(pwd)/${ZIP_NAME}"
echo "Recipient: unzip, move to /Applications, right-click → Open (first launch only)"
