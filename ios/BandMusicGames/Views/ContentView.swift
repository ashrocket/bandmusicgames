import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var auth: SpotifyAuthManager
    @State private var selectedIndex    = 0
    @State private var launchingSong: Song? = nil
    @State private var selectionTrigger = 0
    @State private var launchTask: Task<Void, Never>? = nil
    @State private var showSpotifySheet = false

    private var songs: [Song] { Song.catalog }

    var body: some View {
        ZStack {
            Color(hex: "#06070B")
                .ignoresSafeArea()

            RadialGradient(
                colors: [
                    Song.catalog[selectedIndex].color.opacity(0.16),
                    Color.clear,
                ],
                center: .center,
                startRadius: 0,
                endRadius: 420
            )
            .ignoresSafeArea()

            JukeboxView(
                selectedIndex: $selectedIndex,
                selectionTrigger: selectionTrigger,
                onPlay: handlePlay,
                onShowSpotify: { showSpotifySheet = true },
                onSkip: { auth.skipSpotify() }
            )
        }
        .fullScreenCover(item: $launchingSong) { song in
            switch nativeGame(for: song) {
            case .francis:
                FrancisGameView()
                    .environmentObject(auth)
            case .lizzyMcGuire:
                LizzyMcGuireGameView()
                    .environmentObject(auth)
            case .forCuttingGrass:
                ForCuttingGrassGameView()
                    .environmentObject(auth)
            case nil:
                GameSheetView(song: song, spotifyToken: auth.accessToken)
            }
        }
        .fullScreenCover(isPresented: $showSpotifySheet) {
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
        .onDisappear {
            launchTask?.cancel()
        }
    }

    // MARK: - Actions

    private func handlePlay() {
        let song = songs[selectedIndex]

        guard song.unlocked else {
            HapticManager.notification(.error)
            return
        }

        let isNative = nativeGame(for: song) != nil
        if !auth.isConnected && !isNative {
            showSpotifySheet = true
            return
        }

        // Toggle pause if this song is already playing
        if auth.isPlaying && auth.currentTrackUri == song.trackUri {
            Task { await auth.pausePlayback() }
            return
        }

        HapticManager.impact(.heavy)
        selectionTrigger &+= 1

        // Kick off native Spotify playback (best effort — game handles its own if this fails)
        if auth.accessToken != nil {
            Task { await auth.playTrack(song.trackUri) }
        }

        launchTask?.cancel()
        launchTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_540_000_000)
            guard !Task.isCancelled else { return }
            launchingSong = song
        }
    }

    private enum NativeGame {
        case francis
        case lizzyMcGuire
        case forCuttingGrass
    }

    private func nativeGame(for song: Song) -> NativeGame? {
        if song.id == "francis" {
            return .francis
        }

        if song.id == "narasroom"
            || song.gameUrl.localizedCaseInsensitiveContains("lizzymcguire")
            || song.title.localizedCaseInsensitiveContains("lizzy") {
            return .lizzyMcGuire
        }

        if song.title.localizedCaseInsensitiveCompare("FOR CUTTING GRASS") == .orderedSame
            || song.id == "goon" {
            return .forCuttingGrass
        }

        return nil
    }
}


#Preview {
    ContentView()
        .environmentObject(SpotifyAuthManager())
}
