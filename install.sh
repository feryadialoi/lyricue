#!/bin/bash
APP="SpotifyPinyinLyric.app"
DEST="/Applications/${APP}"

echo "Installing Spotify Pinyin Lyric..."

# Copy to Applications
cp -r "$(dirname "$0")/${APP}" "/Applications/"

# Remove quarantine flag that causes the "damaged" error
xattr -cr "${DEST}"

echo "Done! Launch from Applications or Spotlight."
open "${DEST}"
