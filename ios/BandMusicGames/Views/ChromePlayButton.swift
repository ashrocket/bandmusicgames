import SwiftUI

/// The big chrome PLAY/PAUSE button at the bottom of the jukebox.
struct ChromePlayButton: View {
    let action: () -> Void
    let isConnected: Bool
    let song: Song
    let isCurrentSongPlaying: Bool

    @State private var pressed = false
    @State private var glowPulse = false

    var body: some View {
        Button(action: {
            HapticManager.impact(.heavy)
            action()
        }) {
            ZStack {
                // Outer chrome ring
                Circle()
                    .fill(outerRingGradient)
                    .shadow(color: .black.opacity(0.55), radius: 8, y: 5)

                // Playing glow halo
                if isCurrentSongPlaying {
                    Circle()
                        .fill(song.color.opacity(glowPulse ? 0.25 : 0.08))
                        .scaleEffect(glowPulse ? 1.15 : 1.0)
                        .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: glowPulse)
                }

                // Middle inset ring
                Circle()
                    .fill(middleRingGradient)
                    .padding(8)

                // Inner button face
                Circle()
                    .fill(innerFaceGradient)
                    .padding(16)
                    .scaleEffect(pressed ? 0.94 : 1.0)
                    .animation(.easeInOut(duration: 0.1), value: pressed)

                // Song color ambient glow on face
                if isConnected && song.unlocked {
                    Circle()
                        .fill(song.color.opacity(isCurrentSongPlaying ? 0.28 : 0.14))
                        .padding(16)
                        .animation(.easeInOut(duration: 0.4), value: isCurrentSongPlaying)
                }

                // Label
                VStack(spacing: 3) {
                    Image(systemName: isCurrentSongPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 20, weight: .black))
                        .foregroundStyle(labelGradient)
                    Text(isCurrentSongPlaying ? "PAUSE" : "PLAY")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .tracking(4)
                        .foregroundStyle(labelGradient)
                }
                .scaleEffect(pressed ? 0.92 : 1.0)
                .shadow(
                    color: isConnected ? song.color.opacity(isCurrentSongPlaying ? 0.75 : 0.55) : .clear,
                    radius: isCurrentSongPlaying ? 12 : 8
                )
                .animation(.easeInOut(duration: 0.1), value: pressed)
                .animation(.easeInOut(duration: 0.3), value: isCurrentSongPlaying)
            }
            .frame(width: 100, height: 100)
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: 50) {} onPressingChanged: { pressing in
            pressed = pressing
        }
        .onAppear {
            if isCurrentSongPlaying { glowPulse = true }
        }
        .onChange(of: isCurrentSongPlaying) { playing in
            glowPulse = playing
        }
    }

    // MARK: - Gradients

    private var outerRingGradient: RadialGradient {
        RadialGradient(
            colors: [
                Color(red: 0.78, green: 0.70, blue: 0.52),
                Color(red: 0.42, green: 0.36, blue: 0.24),
            ],
            center: .topLeading,
            startRadius: 4,
            endRadius: 80
        )
    }

    private var middleRingGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: Color(red: 0.30, green: 0.24, blue: 0.15), location: 0),
                .init(color: Color(red: 0.18, green: 0.13, blue: 0.08), location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var innerFaceGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: Color(red: 0.88, green: 0.80, blue: 0.60), location: 0.00),
                .init(color: Color(red: 0.68, green: 0.60, blue: 0.42), location: 0.30),
                .init(color: Color(red: 0.92, green: 0.84, blue: 0.64), location: 0.55),
                .init(color: Color(red: 0.60, green: 0.52, blue: 0.36), location: 0.80),
                .init(color: Color(red: 0.82, green: 0.74, blue: 0.55), location: 1.00),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var labelGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.22, green: 0.16, blue: 0.08),
                Color(red: 0.14, green: 0.10, blue: 0.04),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

#Preview {
    ZStack {
        Color(red: 0.10, green: 0.05, blue: 0.03).ignoresSafeArea()
        VStack(spacing: 24) {
            ChromePlayButton(action: {}, isConnected: true, song: Song.catalog[0], isCurrentSongPlaying: false)
            ChromePlayButton(action: {}, isConnected: true, song: Song.catalog[0], isCurrentSongPlaying: true)
        }
    }
}
