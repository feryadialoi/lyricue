#!/bin/bash
set -e

APP_NAME="Lyricue"
APP_BUNDLE="${APP_NAME}.app"
DMG_NAME="${APP_NAME}.dmg"
DMG_STAGING="dmg-staging"

# SwiftUI macros need the full Xcode toolchain, not just Command Line Tools.
if [ -z "${DEVELOPER_DIR}" ] && [ -d /Applications/Xcode.app ]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

echo "Building universal release binary (Apple Silicon + Intel)..."
BUILD_FLAGS=(-c release --arch arm64 --arch x86_64)
swift build "${BUILD_FLAGS[@]}"
RELEASE_BINARY="$(swift build "${BUILD_FLAGS[@]}" --show-bin-path)/${APP_NAME}"

echo "Creating .app bundle..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp "${RELEASE_BINARY}"  "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
cp Info.plist           "${APP_BUNDLE}/Contents/Info.plist"
cp AppIcon.icns         "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"

echo "Ad-hoc signing..."
codesign --sign - --force --deep --preserve-metadata=entitlements "${APP_BUNDLE}"

echo "Creating .dmg..."
rm -rf "${DMG_STAGING}" "${DMG_NAME}"
mkdir "${DMG_STAGING}"
cp -r "${APP_BUNDLE}" "${DMG_STAGING}/"
# Strip quarantine before packaging so the recipient never gets the "damaged" error
xattr -cr "${DMG_STAGING}/${APP_BUNDLE}"
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
echo "Recipient: open DMG, drag app to Applications"
