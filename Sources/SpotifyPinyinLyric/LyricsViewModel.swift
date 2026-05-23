import Foundation
import Combine

@MainActor
final class LyricsViewModel: ObservableObject {
    @Published var currentHanzi: String = ""
    @Published var currentPinyin: String = ""
    @Published var statusMessage: String = "Waiting for Spotify…"
    @Published var showLyrics: Bool = false

    private let spotifyMonitor = SpotifyMonitor()
    private let lyricsService = LyricsService()
    private var cancellables = Set<AnyCancellable>()

    // Track the lyrics we have loaded and which track they belong to.
    private var loadedTrackKey: String = ""
    private var loadedLines: [LyricLine] = []
    private var isLoadingLyrics: Bool = false
    private var noLyricsAvailable: Bool = false

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
            currentHanzi = ""
            currentPinyin = ""
            return
        }

        let trackKey = "\(track.title)|\(track.artist)"

        if trackKey != loadedTrackKey {
            // New track — reset state and fetch lyrics.
            loadedTrackKey = trackKey
            loadedLines = []
            noLyricsAvailable = false
            isLoadingLyrics = true
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

        // Update the displayed lyric line based on current position.
        if !loadedLines.isEmpty {
            updateCurrentLine(position: track.position, trackTitle: track.title)
        }
    }

    private func updateCurrentLine(position: Double, trackTitle: String) {
        // Find the last line whose time is <= current position.
        var activeLine: LyricLine? = nil
        for line in loadedLines {
            if line.time <= position {
                activeLine = line
            } else {
                break
            }
        }

        guard let line = activeLine, !line.text.isEmpty else {
            // Before the first lyric or on an empty line — show track title.
            showLyrics = false
            statusMessage = trackTitle
            return
        }

        let hanzi = line.text
        let pinyin = containsHanzi(hanzi) ? toPinyin(hanzi) : ""

        if hanzi != currentHanzi || pinyin != currentPinyin {
            currentHanzi = hanzi
            currentPinyin = pinyin
            showLyrics = true
        }

        if !showLyrics { showLyrics = true }
    }
}
