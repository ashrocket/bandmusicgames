import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var auth: SpotifyAuthManager
    @State private var selectedIndex    = 0
    @State private var launchingSong: Song? = nil
    @State private var showSpotifySheet = false

    private var songs: [Song] { Song.catalog }

    var body: some View {
        ZStack {
            // Deep dark background behind the cabinet
            Color(red: 0.06, green: 0.03, blue: 0.02)
                .ignoresSafeArea()

            // Subtle warm light on the floor/wall behind the jukebox
            RadialGradient(
                colors: [
                    Color(red: 0.55, green: 0.32, blue: 0.08).opacity(0.22),
                    Color.clear,
                ],
                center: .bottom,
                startRadius: 0,
                endRadius: 350
            )
            .ignoresSafeArea()

            JukeboxView(
                selectedIndex: $selectedIndex,
                onPlay: handlePlay,
                onShowSpotify: { showSpotifySheet = true },
                onSkip: { auth.skipSpotify() }
            )
        }
        .sheet(item: $launchingSong) { song in
            GameSheetView(song: song, spotifyToken: auth.accessToken)
        }
        .sheet(isPresented: $showSpotifySheet) {
            SpotifySheetView()
                .environmentObject(auth)
        }
        .alert(item: $auth.playbackError) { error in
            Alert(
                title: Text("Can't Play"),
                message: Text(error.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    // MARK: - Actions

    private func handlePlay() {
        let song = songs[selectedIndex]

        guard song.unlocked else {
            HapticManager.notification(.error)
            return
        }

        if !auth.isConnected {
            showSpotifySheet = true
            return
        }

        // Toggle pause if this song is already playing
        if auth.isPlaying && auth.currentTrackUri == song.trackUri {
            Task { await auth.pausePlayback() }
            return
        }

        HapticManager.impact(.heavy)

        // Kick off native Spotify playback (best effort — game handles its own if this fails)
        if auth.accessToken != nil {
            Task { await auth.playTrack(song.trackUri) }
        }

        launchingSong = song
    }
}

#Preview {
    ContentView()
        .environmentObject(SpotifyAuthManager())
}
