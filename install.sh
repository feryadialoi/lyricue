#!/bin/bash
# Installs the latest Lyricue release into /Applications.
#   curl -fsSL https://raw.githubusercontent.com/feryadialoi/lyricue/main/install.sh | bash
set -euo pipefail

REPO="feryadialoi/lyricue"
APP="Lyricue.app"
DMG="Lyricue.dmg"

TMP="$(mktemp -d)"
MOUNT="${TMP}/mount"
cleanup() {
    hdiutil detach "${MOUNT}" -quiet 2>/dev/null || true
    rm -rf "${TMP}"
}
trap cleanup EXIT

echo "Downloading ${DMG}..."
if ! curl -fsSL -o "${TMP}/${DMG}" "https://github.com/${REPO}/releases/latest/download/${DMG}"; then
    # Private repository: fall back to the GitHub CLI, which carries your login.
    command -v gh >/dev/null || { echo "Download failed. Install the GitHub CLI (brew install gh) and run: gh auth login"; exit 1; }
    gh release download --repo "${REPO}" --pattern "${DMG}" --dir "${TMP}"
fi

echo "Installing to /Applications..."
mkdir -p "${MOUNT}"
hdiutil attach "${TMP}/${DMG}" -nobrowse -quiet -mountpoint "${MOUNT}"
pkill -x Lyricue 2>/dev/null || true
rm -rf "/Applications/${APP}"
cp -R "${MOUNT}/${APP}" /Applications/
# The app is not notarized; clear the quarantine flag so macOS opens it.
xattr -cr "/Applications/${APP}"

open "/Applications/${APP}"
echo "Done. Lyricue is running in your menu bar."
