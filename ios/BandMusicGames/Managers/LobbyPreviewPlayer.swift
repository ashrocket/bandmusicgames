import AVFoundation
import Foundation

/// Plays 30s iTunes preview clips in reverse catalog order (narasroom → francis → goon → repeat)
/// when the user is not connected to Spotify. Uses .ambient session so it doesn't interrupt
/// other audio and automatically ducks when the game scene takes over.
@MainActor
final class LobbyPreviewPlayer: ObservableObject {
    @Published private(set) var isPlaying = false

    private var player: AVPlayer?
    private var cycleTask: Task<Void, Never>?
    private var previewCache: [String: URL] = [:]

    // Catalog reversed: narasroom, francis, goon
    private let playOrder: [Song] = Array(Song.catalog.reversed())
    private var currentIndex = 0

    func start() {
        guard cycleTask == nil else { return }
        configureAudioSession()
        currentIndex = 0
        cycleTask = Task { await self.runCycle() }
    }

    func stop() {
        cycleTask?.cancel()
        cycleTask = nil
        player?.pause()
        player = nil
        isPlaying = false
    }

    private func configureAudioSession() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    private func runCycle() async {
        while !Task.isCancelled {
            let song = playOrder[currentIndex]

            let url: URL?
            if let cached = previewCache[song.id] {
                url = cached
            } else {
                url = await fetchPreview(for: song)
                if let resolved = url { previewCache[song.id] = resolved }
            }

            if let url {
                playURL(url)
                try? await Task.sleep(nanoseconds: 20_000_000_000)
            } else {
                // No preview found for this song — short pause then advance
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }

            if Task.isCancelled { break }
            currentIndex = (currentIndex + 1) % playOrder.count
        }
        isPlaying = false
    }

    private func playURL(_ url: URL) {
        player?.pause()
        let item = AVPlayerItem(url: url)
        let newPlayer = AVPlayer(playerItem: item)
        newPlayer.volume = 0.65
        newPlayer.play()
        player = newPlayer
        isPlaying = true
    }

    /// Searches iTunes for a 30s preview URL matching the song's title + artist.
    /// Uses soft artist-word matching to avoid playing the wrong track when the
    /// top result is an unrelated song with a similar title.
    private func fetchPreview(for song: Song) async -> URL? {
        let term = "\(song.title) \(song.artist)"
        guard let encoded = term.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let requestURL = URL(string: "https://itunes.apple.com/search?term=\(encoded)&entity=song&limit=5")
        else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: requestURL)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]] else { return nil }

            let ourWords = song.artist.lowercased().components(separatedBy: .whitespaces)

            // Pass 1: prefer results where the artist name shares a word with ours
            for result in results {
                guard let previewStr = result["previewUrl"] as? String,
                      let previewURL = URL(string: previewStr),
                      let trackArtist = result["artistName"] as? String else { continue }
                let theirWords = trackArtist.lowercased().components(separatedBy: .whitespaces)
                if ourWords.contains(where: theirWords.contains) { return previewURL }
            }

            // Pass 2: fallback — return first result with any previewUrl (better than silence)
            for result in results {
                if let previewStr = result["previewUrl"] as? String,
                   let previewURL = URL(string: previewStr) { return previewURL }
            }
        } catch {}
        return nil
    }
}
