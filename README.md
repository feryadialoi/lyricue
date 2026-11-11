# Lyricue

Live Spotify lyrics on your Mac, with the reading shown above every word: pinyin for Chinese, hiragana for Japanese, romanization for Korean.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/feryadialoi/lyricue/main/install.sh | bash
```

This downloads the latest release, copies `Lyricue.app` into `/Applications` and starts it. Run the same command again to update.

On first launch macOS asks to let Lyricue control Spotify. Allow it; that is how Lyricue reads the current track and position. If you clicked "Don't Allow", turn it back on in System Settings > Privacy & Security > Automation.

Requires macOS 13 or later, Apple Silicon or Intel.

## Display modes

Pick one from the music note in the menu bar, under **Display**:

| Mode | What it shows |
|---|---|
| Floating | A pill you can drag anywhere. Starts at the bottom center. |
| Corner | A larger, higher-contrast card pinned to the bottom-right corner, with the track name. |
| Menu Bar | The current line and its reading as scrolling text in the menu bar. |

Lyrics come from [LRCLIB](https://lrclib.net).

## Build from source

Needs Xcode (Command Line Tools alone cannot build the SwiftUI macros).

```bash
bash package.sh   # builds Lyricue.app and Lyricue.dmg (universal binary)
```

## Release

```bash
bash package.sh
gh release create vX.Y.Z Lyricue.dmg --title vX.Y.Z
```
