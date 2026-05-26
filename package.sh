#!/bin/bash
set -e

APP_NAME="SpotifyPinyinLyric"
APP_BUNDLE="${APP_NAME}.app"
RELEASE_BINARY=".build/release/${APP_NAME}"
DMG_NAME="${APP_NAME}.dmg"
DMG_STAGING="dmg-staging"

echo "Building release binary..."
swift build -c release

echo "Creating .app bundle..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp "${RELEASE_BINARY}"  "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
cp Info.plist           "${APP_BUNDLE}/Contents/Info.plist"
cp AppIcon.icns         "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"

echo "Creating .dmg..."
rm -rf "${DMG_STAGING}" "${DMG_NAME}"
mkdir "${DMG_STAGING}"
cp -r "${APP_BUNDLE}" "${DMG_STAGING}/"
cp install.sh "${DMG_STAGING}/Install.command"
chmod +x "${DMG_STAGING}/Install.command"
# Symlink to /Applications so user can drag-and-drop inside the DMG
ln -s /Applications "${DMG_STAGING}/Applications"

hdiutil create \
    -volname "${APP_NAME}" \
    -srcfolder "${DMG_STAGING}" \
    -ov \
    -format UDZO \
    -imagekey zlib-level=9 \
    "${DMG_NAME}"

rm -rf "${DMG_STAGING}"

echo ""
echo "Done! Share: $(pwd)/${DMG_NAME}"
echo "Recipient: open DMG, double-click Install.command to install"
