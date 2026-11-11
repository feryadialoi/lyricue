import Foundation
import AppKit
import QuartzCore

struct SpotifyTrack: Equatable {
    let title: String
    let artist: String
    let position: Double
    let isPaused: Bool
}

@MainActor
final class SpotifyMonitor: ObservableObject {
    @Published var currentTrack: SpotifyTrack? = nil

    // Last confirmed position and the wall-clock time it was received.
    private var lastKnownPosition: Double = 0
    private var lastPollTime: Double = 0
    private var lastTitle: String = ""
    private var lastArtist: String = ""
    private var lastIsPaused: Bool = false

    private var pollTimer: Timer?
    private var interpolationTimer: Timer?

    init() {
        Task { @MainActor [weak self] in await self?.poll() }

        // Poll Spotify every 1s for ground-truth position.
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in await self?.poll() }
        }

        // Interpolate position at 4 Hz between polls for smooth lyric advancement.
        interpolationTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in self?.interpolate() }
        }
    }

    deinit {
        pollTimer?.invalidate()
        interpolationTimer?.invalidate()
    }

    private func interpolate() {
        guard !lastTitle.isEmpty, !lastIsPaused else { return }
        let elapsed = CACurrentMediaTime() - lastPollTime
        let interpolated = lastKnownPosition + elapsed
        currentTrack = SpotifyTrack(
            title: lastTitle,
            artist: lastArtist,
            position: interpolated,
            isPaused: false
        )
    }

    private func poll() async {
        let script = """
        tell application "Spotify"
            set playerSt to player state
            if playerSt is stopped then return ""
            set trackName to name of current track
            set artistName to artist of current track
            set pos to player position
            if playerSt is paused then
                set isPausedStr to "true"
            else
                set isPausedStr to "false"
            end if
            return trackName & "|" & artistName & "|" & pos & "|" & isPausedStr
        end tell
        """

        let pollStartTime = CACurrentMediaTime()

        let result: String? = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInteractive).async {
                var error: NSDictionary?
                let appleScript = NSAppleScript(source: script)
                let descriptor = appleScript?.executeAndReturnError(&error)
                continuation.resume(returning: descriptor?.stringValue)
            }
        }

        guard let result, !result.isEmpty else {
            lastTitle = ""
            currentTrack = nil
            return
        }

        let parts = result.components(separatedBy: "|")
        guard parts.count >= 3 else {
            lastTitle = ""
            currentTrack = nil
            return
        }

        let title = parts[0]
        let artist = parts[1]
        let posString = parts[2].trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedPos = posString.replacingOccurrences(of: ",", with: ".")
        let position = Double(normalizedPos) ?? 0.0
        let isPaused = parts.count >= 4 && parts[3].trimmingCharacters(in: .whitespacesAndNewlines) == "true"

        // Account for time elapsed during the AppleScript call itself.
        let callDuration = CACurrentMediaTime() - pollStartTime
        let correctedPosition = isPaused ? position : position + callDuration

        lastTitle = title
        lastArtist = artist
        lastKnownPosition = correctedPosition
        lastPollTime = CACurrentMediaTime()
        lastIsPaused = isPaused

        currentTrack = SpotifyTrack(title: title, artist: artist, position: correctedPosition, isPaused: isPaused)
    }
}
