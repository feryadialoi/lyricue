import Foundation

struct LyricLine: Equatable {
    let time: Double
    let text: String
}

actor LyricsService {
    // Simple in-memory cache keyed by "title|artist"
    private var cache: [String: [LyricLine]] = [:]
    // Track inflight requests so we don't double-fetch
    private var inflight: [String: Task<[LyricLine], Error>] = [:]

    func lyrics(for title: String, artist: String) async throws -> [LyricLine] {
        let key = "\(title)|\(artist)"

        if let cached = cache[key] {
            return cached
        }

        // Reuse an in-flight task if one exists.
        if let existing = inflight[key] {
            return try await existing.value
        }

        let task = Task<[LyricLine], Error> {
            let lines = try await fetchAndParse(title: title, artist: artist)
            return lines
        }

        inflight[key] = task

        do {
            let lines = try await task.value
            cache[key] = lines
            inflight.removeValue(forKey: key)
            return lines
        } catch {
            inflight.removeValue(forKey: key)
            throw error
        }
    }

    private func fetchAndParse(title: String, artist: String) async throws -> [LyricLine] {
        // Try exact match first, then fall back to search.
        if let lines = try await fetchExact(title: title, artist: artist) {
            return lines
        }
        return try await fetchViaSearch(title: title, artist: artist)
    }

    private func fetchExact(title: String, artist: String) async throws -> [LyricLine]? {
        guard let encodedArtist = artist.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let encodedTitle = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://lrclib.net/api/get?artist_name=\(encodedArtist)&track_name=\(encodedTitle)") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.setValue("SpotifyPinyinLyric/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }

        if http.statusCode == 404 { return nil }
        guard http.statusCode == 200 else { throw URLError(.badServerResponse) }

        struct LRCLibResponse: Decodable { let syncedLyrics: String? }
        let decoded = try JSONDecoder().decode(LRCLibResponse.self, from: data)
        guard let lrcText = decoded.syncedLyrics, !lrcText.isEmpty else { return [] }
        return parseLRC(lrcText)
    }

    private func fetchViaSearch(title: String, artist: String) async throws -> [LyricLine] {
        // Build a search query from the artist + a simplified title (strip parentheticals).
        let simplifiedTitle = title
            .replacingOccurrences(of: "\\s*[（(][^）)]*[）)]", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        let query = "\(simplifiedTitle) \(artist)"
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://lrclib.net/api/search?q=\(encoded)") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.setValue("SpotifyPinyinLyric/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return [] }

        struct SearchResult: Decodable {
            let artistName: String
            let syncedLyrics: String?
        }

        let results = try JSONDecoder().decode([SearchResult].self, from: data)

        // Pick the first result whose artist roughly matches.
        let artistLower = artist.lowercased()
        let best = results.first { $0.artistName.lowercased() == artistLower }
                ?? results.first { $0.artistName.lowercased().contains(artistLower) || artistLower.contains($0.artistName.lowercased()) }
                ?? results.first

        guard let lrcText = best?.syncedLyrics, !lrcText.isEmpty else { return [] }
        return parseLRC(lrcText)
    }

    // MARK: - LRC Parser
    // Format: [mm:ss.xx] lyric text
    private func parseLRC(_ text: String) -> [LyricLine] {
        let lines = text.components(separatedBy: .newlines)
        var result: [LyricLine] = []

        // Regex: [digits:digits.digits] text
        // We'll parse manually for speed and no Regex dependency.
        for line in lines {
            guard line.hasPrefix("[") else { continue }
            guard let closeBracket = line.firstIndex(of: "]") else { continue }

            let timestampPart = line[line.index(after: line.startIndex)..<closeBracket]
            let textPart = String(line[line.index(after: closeBracket)...]).trimmingCharacters(in: .whitespaces)

            // Parse mm:ss.xx or mm:ss.xxx
            let parts = timestampPart.components(separatedBy: ":")
            guard parts.count == 2,
                  let minutes = Double(parts[0]),
                  let seconds = Double(parts[1]) else { continue }

            let totalSeconds = minutes * 60.0 + seconds
            result.append(LyricLine(time: totalSeconds, text: textPart))
        }

        return result.sorted { $0.time < $1.time }
    }
}
