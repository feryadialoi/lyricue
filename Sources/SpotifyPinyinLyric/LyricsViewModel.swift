import Foundation
import Combine

@MainActor
final class LyricsViewModel: ObservableObject {
    @Published var currentHanzi: String = ""
    @Published var currentPinyin: String = ""
    @Published var nextHanzi: String = ""
    @Published var nextPinyin: String = ""
    @Published var statusMessage: String = "Waiting for Spotify…"
    @Published var showLyrics: Bool = false
    @Published var isPaused: Bool = false

    private let spotifyMonitor = SpotifyMonitor()
    private let lyricsService = LyricsService()
    private var cancellables = Set<AnyCancellable>()

    private var loadedTrackKey: String = ""
    private var loadedLines: [LyricLine] = []
    private var isLoadingLyrics: Bool = false
    private var noLyricsAvailable: Bool = false
    private var lastActiveIndex: Int = -1

    init() {
        spotifyMonitor.$currentTrack
            .receive(on: RunLoop.main)
            .sink { [weak self] track in
                self?.handleTrackUpdate(track)
            }
            .store(in: &cancellables)
    }

    private func handleTrackUpdate(_ track: SpotifyTrack?) {
        guard let track else {
            statusMessage = "No track playing"
            showLyrics = false
            isPaused = false
            currentHanzi = ""
            currentPinyin = ""
            nextHanzi = ""
            nextPinyin = ""
            return
        }

        isPaused = track.isPaused

        let trackKey = "\(track.title)|\(track.artist)"

        if trackKey != loadedTrackKey {
            loadedTrackKey = trackKey
            loadedLines = []
            noLyricsAvailable = false
            isLoadingLyrics = true
            lastActiveIndex = -1
            showLyrics = false
            statusMessage = "Loading lyrics for \(track.title)…"

            Task {
                do {
                    let lines = try await lyricsService.lyrics(for: track.title, artist: track.artist)
                    if self.loadedTrackKey == trackKey {
                        self.loadedLines = lines
                        self.isLoadingLyrics = false
                        if lines.isEmpty {
                            self.noLyricsAvailable = true
                            self.statusMessage = track.title
                            self.showLyrics = false
                        }
                    }
                } catch {
                    if self.loadedTrackKey == trackKey {
                        self.isLoadingLyrics = false
                        self.noLyricsAvailable = true
                        self.statusMessage = "Lyrics not available"
                        self.showLyrics = false
                    }
                }
            }
        }

        if !loadedLines.isEmpty {
            updateCurrentLine(position: track.position, trackTitle: track.title)
        }
    }

    private static let lyricLeadSeconds: Double = 0.3

    private func updateCurrentLine(position: Double, trackTitle: String) {
        let adjustedPosition = position + Self.lyricLeadSeconds

        var activeIndex: Int = -1
        for (i, line) in loadedLines.enumerated() {
            if line.time <= adjustedPosition {
                activeIndex = i
            } else {
                break
            }
        }

        guard activeIndex >= 0 else {
            showLyrics = false
            statusMessage = trackTitle
            lastActiveIndex = -1
            nextHanzi = ""
            nextPinyin = ""
            return
        }

        // If the current line is empty (interlude/gap), keep showing the last
        // non-empty line so the display doesn't flicker back to the track title.
        let resolvedIndex: Int
        if loadedLines[activeIndex].text.isEmpty {
            // Find the most recent non-empty line before this position.
            if let lastNonEmpty = (0..<activeIndex).reversed().first(where: { !loadedLines[$0].text.isEmpty }) {
                resolvedIndex = lastNonEmpty
            } else {
                // Still before the first lyric — show track title
                showLyrics = false
                statusMessage = trackTitle
                nextHanzi = ""
                nextPinyin = ""
                return
            }
        } else {
            resolvedIndex = activeIndex
        }

        // Next non-empty line
        let nextLine = loadedLines[(resolvedIndex + 1)...].first { !$0.text.isEmpty }
        let newNextHanzi = nextLine?.text ?? ""
        let newNextPinyin = newNextHanzi.isEmpty ? "" : (containsHanzi(newNextHanzi) ? toPinyin(newNextHanzi) : "")

        let line = loadedLines[resolvedIndex]
        let newHanzi = line.text
        let newPinyin = containsHanzi(newHanzi) ? toPinyin(newHanzi) : ""

        if newHanzi != currentHanzi || newPinyin != currentPinyin {
            currentHanzi = newHanzi
            currentPinyin = newPinyin
            lastActiveIndex = activeIndex
        }

        if newNextHanzi != nextHanzi || newNextPinyin != nextPinyin {
            nextHanzi = newNextHanzi
            nextPinyin = newNextPinyin
        }

        if !showLyrics { showLyrics = true }
    }
}
