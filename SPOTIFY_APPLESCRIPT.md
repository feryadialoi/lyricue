# Controlling Spotify via Terminal (AppleScript)

All commands use `osascript -e '...'` to send AppleScript to Spotify.

## Playback

```bash
# Play / pause toggle
osascript -e 'tell application "Spotify" to playpause'

# Play
osascript -e 'tell application "Spotify" to play'

# Pause
osascript -e 'tell application "Spotify" to pause'

# Next track
osascript -e 'tell application "Spotify" to next track'

# Previous track
osascript -e 'tell application "Spotify" to previous track'
```

## Volume

```bash
# Set volume (0–100)
osascript -e 'tell application "Spotify" to set sound volume to 50'

# Get current volume
osascript -e 'tell application "Spotify" to get sound volume'
```

## Seeking

```bash
# Seek to position (seconds)
osascript -e 'tell application "Spotify" to set player position to 30'

# Get current position
osascript -e 'tell application "Spotify" to get player position'
```

## Track Info

```bash
# Track name
osascript -e 'tell application "Spotify" to get name of current track'

# Artist
osascript -e 'tell application "Spotify" to get artist of current track'

# Album
osascript -e 'tell application "Spotify" to get album of current track'

# Player state (playing / paused / stopped)
osascript -e 'tell application "Spotify" to get player state'

# All at once
osascript -e 'tell application "Spotify"
    set t to name of current track
    set a to artist of current track
    set p to player position
    return t & " — " & a & " @ " & p & "s"
end tell'
```

## Overlay App

```bash
# Run in background
.build/release/Lyricue &

# Run in foreground (Cmd+C or Cmd+Q to stop)
.build/release/Lyricue

# Kill
pkill Lyricue

# Check if running
pgrep -l Lyricue
```
