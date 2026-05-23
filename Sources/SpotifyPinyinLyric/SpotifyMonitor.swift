import Foundation
import AppKit

struct SpotifyTrack: Equatable {
    let title: String
    let artist: String
    let position: Double
    let isPaused: Bool
}

@MainActor
final class SpotifyMonitor: ObservableObject {
    @Published var currentTrack: SpotifyTrack? = nil

    private var timer: Timer?

    init() {
        // Poll immediately, then every 2 seconds.
        Task { @MainActor [weak self] in
            await self?.poll()
        }
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                await self?.poll()
            }
        }
    }

    deinit {
        timer?.invalidate()
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

        // NSAppleScript is thread-safe for execution; run on a background thread
        // to avoid blocking the main thread.
        let result: String? = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                var error: NSDictionary?
                let appleScript = NSAppleScript(source: script)
                let descriptor = appleScript?.executeAndReturnError(&error)
                continuation.resume(returning: descriptor?.stringValue)
            }
        }

        guard let result, !result.isEmpty else {
            self.currentTrack = nil
            return
        }

        let parts = result.components(separatedBy: "|")
        guard parts.count >= 3 else {
            self.currentTrack = nil
            return
        }

        let title = parts[0]
        let artist = parts[1]
        let posString = parts[2].trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedPos = posString.replacingOccurrences(of: ",", with: ".")
        let position = Double(normalizedPos) ?? 0.0
        let isPaused = parts.count >= 4 && parts[3].trimmingCharacters(in: .whitespacesAndNewlines) == "true"
        self.currentTrack = SpotifyTrack(title: title, artist: artist, position: position, isPaused: isPaused)
    }
}
