import SwiftUI

struct ContentView: View {
    /// Test mode: boot straight into the Lizzie McGuire game lobby.
    /// Flip to false to restore the normal jukebox-first flow.
    private static let autoLaunchLizzyLobby = true

    @EnvironmentObject private var auth: SpotifyAuthManager
    @State private var selectedIndex    = 0
    @State private var launchingSong: Song? = nil
    @State private var selectionTrigger = 0
    @State private var launchTask: Task<Void, Never>? = nil
    @State private var showSpotifySheet = false
    @State private var didAutoLaunch = false

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
        .ignoresSafeArea()
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
        .overlay {
            if let error = auth.playbackError {
                spotifyErrorOverlay(error)
            }
        }
        .onDisappear {
            launchTask?.cancel()
        }
        .onAppear {
            guard Self.autoLaunchLizzyLobby, !didAutoLaunch else { return }
            didAutoLaunch = true
            if let song = songs.first(where: { nativeGame(for: $0) == .lizzyMcGuire }) {
                selectedIndex = songs.firstIndex(of: song) ?? selectedIndex
                launchingSong = song
            }
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

        HapticManager.impact(.heavy)
        selectionTrigger &+= 1

        // Kick off Spotify playback if available; the center action always cues the game launch.
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

    private func spotifyErrorOverlay(_ error: SpotifyAuthManager.PlaybackError) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(.orange)
            
            Text("SPOTIFY ERROR")
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .tracking(2)
                .foregroundColor(.white)
            
            Text(error.message)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .foregroundColor(.white.opacity(0.8))

            HStack(spacing: 12) {
                if case .noDevice = error {
                    Button {
                        auth.wakeSpotify()
                        auth.playbackError = nil
                    } label: {
                        Text("WAKE SPOTIFY")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.green)
                            .foregroundColor(.black)
                            .clipShape(Capsule())
                    }
                }
                
                Button {
                    auth.playbackError = nil
                } label: {
                    Text("DISMISS")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.1))
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.vertical, 32)
        .frame(maxWidth: 320)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(red: 0.1, green: 0.05, blue: 0.02))
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.1), lineWidth: 1))
        )
        .shadow(color: .black.opacity(0.6), radius: 40)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .zIndex(999)
    }
}


#Preview {
    ContentView()
        .environmentObject(SpotifyAuthManager())
}
