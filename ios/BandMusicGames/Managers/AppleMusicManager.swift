import Foundation
import MusicKit

/// Manages Apple Music playback as an alternative to Spotify Connect.
/// Inject as @EnvironmentObject alongside SpotifyAuthManager.
/// When isPreferred == true, game views route playback here instead of Spotify.
@MainActor
final class AppleMusicManager: ObservableObject {

    @Published private(set) var authStatus: MusicAuthorization.Status = .notDetermined
    @Published private(set) var canPlayCatalog = false
    @Published private(set) var isPlaying = false
    @Published private(set) var currentTrackId: String? = nil
    @Published var isPreferred: Bool {
        didSet { UserDefaults.standard.set(isPreferred, forKey: "am_preferred") }
    }

    private var subscriptionTask: Task<Void, Never>?

    init() {
        isPreferred = UserDefaults.standard.bool(forKey: "am_preferred")
        authStatus  = MusicAuthorization.currentStatus
        startSubscriptionMonitor()
    }

    deinit {
        subscriptionTask?.cancel()
    }

    // MARK: - Auth / activation

    /// Called when the user taps "Switch to Apple Music" in the error banner.
    /// Requests authorization, checks subscription, and sets isPreferred on success.
    func activateAsPreferred() async {
        let status = await MusicAuthorization.request()
        authStatus = status
        guard status == .authorized else { return }
        // canPlayCatalog is updated by the subscription monitor; give it a moment
        // to fire before committing the preference.
        try? await Task.sleep(nanoseconds: 300_000_000)
        if canPlayCatalog {
            isPreferred = true
        }
    }

    func deactivate() {
        isPreferred = false
        pause()
    }

    // MARK: - Playback

    /// Play a track by its Apple Music catalog ID (numeric string from iTunes Lookup).
    func play(trackId: String) async {
        guard authStatus == .authorized, canPlayCatalog else { return }
        do {
            var req = MusicCatalogResourceRequest<MusicKit.Song>(
                matching: \.id, equalTo: MusicItemID(rawValue: trackId)
            )
            req.limit = 1
            let response = try await req.response()
            guard let song = response.items.first else {
                print("AppleMusic: track \(trackId) not found in catalog")
                return
            }
            // ApplicationMusicPlayer.Queue(for:) takes any PlayableMusicItem sequence
            ApplicationMusicPlayer.shared.queue = ApplicationMusicPlayer.Queue(for: [song])
            try await ApplicationMusicPlayer.shared.play()
            ApplicationMusicPlayer.shared.state.repeatMode = .one
            currentTrackId = trackId
            isPlaying = true
        } catch {
            print("AppleMusic: play failed: \(error)")
        }
    }

    func pause() {
        ApplicationMusicPlayer.shared.pause()
        isPlaying = false
    }

    func resume() async {
        do {
            try await ApplicationMusicPlayer.shared.play()
            isPlaying = true
        } catch {
            print("AppleMusic: resume failed: \(error)")
        }
    }

    func isCurrentlyPlaying(trackId: String) -> Bool {
        isPlaying && currentTrackId == trackId
    }

    // MARK: - Private

    private func startSubscriptionMonitor() {
        subscriptionTask = Task {
            for await state in MusicSubscription.subscriptionUpdates {
                self.canPlayCatalog = state.canPlayCatalogContent
                // If preferred but subscription lapsed, fall back to Spotify
                if self.isPreferred && !state.canPlayCatalogContent {
                    self.isPreferred = false
                }
            }
        }
    }
}
