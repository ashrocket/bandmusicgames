import SwiftUI

/// The full jukebox cabinet: arch header, bubble tubes, display window,
/// play button, and speaker grille.
struct JukeboxView: View {
    @Binding var selectedIndex: Int
    let onPlay: () -> Void
    let onShowSpotify: () -> Void
    let onSkip: () -> Void

    @EnvironmentObject private var auth: SpotifyAuthManager

    @State private var cabinetGlow = false

    private let songs = Song.catalog

    private var currentSong: Song { songs[selectedIndex] }
    private var isCurrentSongPlaying: Bool {
        auth.isPlaying && auth.currentTrackUri == currentSong.trackUri
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                cabinetBackground(in: geo.size)

                // Ambient playing glow behind the cabinet
                if isCurrentSongPlaying {
                    RoundedRectangle(cornerRadius: 28)
                        .fill(
                            RadialGradient(
                                colors: [
                                    currentSong.color.opacity(cabinetGlow ? 0.22 : 0.08),
                                    Color.clear,
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 220
                            )
                        )
                        .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: cabinetGlow)
                }

                VStack(spacing: 0) {
                    // Arch header
                    ArchHeaderView()
                        .frame(height: archHeight(for: geo.size))
                        .padding(.horizontal, cabinetHPad)

                    Spacer(minLength: 10)

                    // Body: bubble tubes flanking the display
                    HStack(alignment: .center, spacing: 0) {
                        BubbleTubeView(bubbleColors: [
                            Color(hex: "#FF4E50"),
                            Color(hex: "#FFA500"),
                            Color(hex: "#FFD700"),
                        ])
                        .frame(width: 26)

                        SongDisplayView(
                            songs: songs,
                            selectedIndex: $selectedIndex,
                            isConnected: auth.isConnected,
                            currentTrackUri: auth.currentTrackUri,
                            onPlay: onPlay,
                            onShowSpotify: onShowSpotify,
                            onSkip: onSkip
                        )
                        .padding(.horizontal, 10)

                        BubbleTubeView(bubbleColors: [
                            Color(hex: "#00CED1"),
                            Color(hex: "#A855F7"),
                            Color(hex: "#00FF88"),
                        ])
                        .frame(width: 26)
                    }
                    .padding(.horizontal, cabinetHPad + 4)
                    .frame(height: displayHeight(for: geo.size))

                    Spacer(minLength: 12)

                    // Play button
                    ChromePlayButton(
                        action: onPlay,
                        isConnected: auth.isConnected,
                        song: currentSong,
                        isCurrentSongPlaying: isCurrentSongPlaying
                    )

                    Spacer(minLength: 14)

                    // Speaker grille
                    speakerGrille
                        .padding(.horizontal, cabinetHPad + 8)
                        .frame(height: 44)

                    Spacer(minLength: 12)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .overlay(
                RoundedRectangle(cornerRadius: 28)
                    .stroke(outerChrome, lineWidth: 5)
            )
            .shadow(color: .black.opacity(0.7), radius: 20, y: 10)
            .padding(16)
        }
        .onAppear { cabinetGlow = isCurrentSongPlaying }
        .onChange(of: isCurrentSongPlaying) { playing in
            cabinetGlow = playing
        }
    }

    // MARK: - Sub-views

    private func cabinetBackground(in size: CGSize) -> some View {
        RoundedRectangle(cornerRadius: 28)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.20, green: 0.11, blue: 0.06),
                        Color(red: 0.13, green: 0.07, blue: 0.04),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }

    private var speakerGrille: some View {
        VStack(spacing: 5) {
            ForEach(0..<6, id: \.self) { _ in
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.28, green: 0.18, blue: 0.10),
                                Color(red: 0.18, green: 0.10, blue: 0.05),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 3)
                    .clipShape(RoundedRectangle(cornerRadius: 1.5))
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(red: 0.10, green: 0.06, blue: 0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(red: 0.38, green: 0.28, blue: 0.16).opacity(0.6), lineWidth: 1.5)
                )
        )
    }

    // MARK: - Layout helpers

    private let cabinetHPad: CGFloat = 12

    private func archHeight(for size: CGSize) -> CGFloat {
        min(size.height * 0.17, 130)
    }

    private func displayHeight(for size: CGSize) -> CGFloat {
        let used = archHeight(for: size)
            + 10     // top spacer
            + 100    // play button
            + 44     // grille
            + 12     // bottom spacer
            + 14     // spacer before grille
            + 12     // spacer after grille
        return max(size.height - used - 32 /*cabinet padding*/, 220)
    }

    // MARK: - Gradients

    private var outerChrome: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: Color(red: 0.90, green: 0.82, blue: 0.60), location: 0.00),
                .init(color: Color(red: 0.50, green: 0.44, blue: 0.30), location: 0.30),
                .init(color: Color(red: 0.92, green: 0.86, blue: 0.64), location: 0.55),
                .init(color: Color(red: 0.48, green: 0.42, blue: 0.28), location: 0.80),
                .init(color: Color(red: 0.88, green: 0.80, blue: 0.58), location: 1.00),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

#Preview {
    ZStack {
        Color(red: 0.06, green: 0.03, blue: 0.02).ignoresSafeArea()
        JukeboxView(
            selectedIndex: .constant(0),
            onPlay: {},
            onShowSpotify: {},
            onSkip: {}
        )
        .environmentObject(SpotifyAuthManager())
    }
}
