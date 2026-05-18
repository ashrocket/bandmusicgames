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
        .fullScreenCover(item: $launchingSong) { song in
            switch nativeGame(for: song) {
            case .francis:
                FrancisGameView()
                    .environmentObject(auth)
            case .lizzyMcGuire:
                LizzyMcGuireGameView()
                    .environmentObject(auth)
            case .goon:
                GoonGameView()
                    .environmentObject(auth)
            case .frattypipeline:
                FrattypipelineGameView(autoplayDemo: frattypipelineAutoplayDemo)
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
        .onAppear(perform: handleLaunchArguments)
    }

    // MARK: - Actions

    private func handleLaunchArguments() {
#if DEBUG
        let args = ProcessInfo.processInfo.arguments
        let targetId: String?
        if args.contains("-bmg-open-goon") {
            targetId = "goon"
        } else if args.contains("-bmg-open-frattypipeline") {
            targetId = "frattypipeline"
        } else if args.contains("-bmg-open-francis") {
            targetId = "francis"
        } else if args.contains("-bmg-open-lizzy") {
            targetId = "narasroom"
        } else {
            targetId = nil
        }

        guard launchingSong == nil,
              let targetId,
              let song = songs.first(where: { $0.id == targetId })
        else { return }

        selectedIndex = songs.firstIndex(of: song) ?? selectedIndex
        launchingSong = song
#endif
    }

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

        // Kick off native Spotify playback (best effort — game handles its own if this fails)
        if auth.accessToken != nil {
            Task { await auth.playTrack(song.trackUri) }
        }

        launchingSong = song
    }

    private var frattypipelineAutoplayDemo: Bool {
#if DEBUG
        ProcessInfo.processInfo.arguments.contains("-bmg-frattypipeline-autoplay")
#else
        false
#endif
    }

    private enum NativeGame {
        case francis
        case lizzyMcGuire
        case goon
        case frattypipeline
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

        if song.id == "goon" {
            return .goon
        }

        if song.id == "frattypipeline" {
            return .frattypipeline
        }

        return nil
    }
}

#Preview {
    ContentView()
        .environmentObject(SpotifyAuthManager())
}
