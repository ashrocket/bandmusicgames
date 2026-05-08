import SwiftUI

/// The illuminated display window in the center of the jukebox.
/// Shows the current song and handles swipe / arrow navigation.
struct SongDisplayView: View {
    let songs: [Song]
    @Binding var selectedIndex: Int
    let isConnected: Bool
    let currentTrackUri: String?
    let onPlay: () -> Void
    let onShowSpotify: () -> Void
    let onSkip: () -> Void

    @State private var direction: NavigationDirection = .forward
    @State private var dragStartY: CGFloat = 0

    enum NavigationDirection { case forward, backward }

    private var song: Song { songs[selectedIndex] }
    private var isThisSongPlaying: Bool { currentTrackUri == song.trackUri }

    var body: some View {
        ZStack {
            // Dark glass background + song color ambient glow
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(red: 0.04, green: 0.04, blue: 0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(
                            RadialGradient(
                                colors: [
                                    song.color.opacity(isConnected && song.unlocked ? 0.14 : 0.04),
                                    Color.clear,
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 180
                            )
                        )
                )
                .animation(.easeInOut(duration: 0.6), value: selectedIndex)

            // Chrome bezel
            RoundedRectangle(cornerRadius: 18)
                .stroke(displayChrome, lineWidth: 5)

            VStack(spacing: 0) {
                if isConnected {
                    connectedContent
                } else {
                    disconnectedContent
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
        .gesture(swipeDragGesture)
    }

    // MARK: - Connected state

    private var connectedContent: some View {
        VStack(spacing: 0) {
            // Song counter badge + now playing indicator
            HStack {
                Text(jukeboxCode(for: selectedIndex))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(2)
                    .foregroundColor(song.color.opacity(0.85))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(song.color.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 5))

                if isThisSongPlaying {
                    NowPlayingBadge(color: song.color)
                        .transition(.scale.combined(with: .opacity))
                }

                Spacer()
                Text("\(selectedIndex + 1) / \(songs.count)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .tracking(1)
                    .foregroundColor(Color(red: 0.65, green: 0.55, blue: 0.35).opacity(0.7))
            }
            .animation(.spring(duration: 0.35), value: isThisSongPlaying)
            .padding(.bottom, 16)

            Spacer(minLength: 0)

            // Song title — flip-slides when changing songs
            ZStack {
                songTitleCard
                    .id(selectedIndex)
                    .transition(
                        direction == .forward
                            ? .asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal:   .move(edge: .top).combined(with: .opacity)
                            )
                            : .asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal:   .move(edge: .bottom).combined(with: .opacity)
                            )
                    )
            }
            .animation(.easeInOut(duration: 0.28), value: selectedIndex)
            .frame(maxHeight: .infinity)

            Spacer(minLength: 0)

            // Navigation arrows
            navigationRow
                .padding(.top, 16)
        }
    }

    private var songTitleCard: some View {
        VStack(spacing: 8) {
            Text(song.unlocked ? song.title : "???")
                .font(.system(size: 22, weight: .black, design: .serif))
                .tracking(3)
                .multilineTextAlignment(.center)
                .foregroundStyle(
                    song.unlocked
                        ? LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.96, blue: 0.88),
                                Color(red: 0.95, green: 0.88, blue: 0.72),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                          )
                        : LinearGradient(colors: [.gray.opacity(0.5), .gray.opacity(0.3)],
                                         startPoint: .top, endPoint: .bottom)
                )
                .shadow(color: song.color.opacity(isThisSongPlaying ? 0.9 : 0.6), radius: isThisSongPlaying ? 12 : 8)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .animation(.easeInOut(duration: 0.4), value: isThisSongPlaying)

            if song.unlocked {
                Text(song.artist)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .tracking(3)
                    .foregroundColor(Color(red: 0.95, green: 0.70, blue: 0.28))

                Text(song.gameName)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .tracking(2)
                    .foregroundColor(Color(red: 0.65, green: 0.55, blue: 0.38).opacity(0.7))
            } else {
                Text("COMING SOON")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .tracking(3)
                    .foregroundColor(.gray.opacity(0.5))
            }
        }
    }

    private var navigationRow: some View {
        HStack(spacing: 0) {
            Button { navigate(backward: true) } label: {
                Image(systemName: "chevron.up")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color(red: 0.80, green: 0.65, blue: 0.35))
                    .frame(width: 44, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(red: 0.10, green: 0.08, blue: 0.05).opacity(0.8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(red: 0.50, green: 0.42, blue: 0.28).opacity(0.5), lineWidth: 1)
                            )
                    )
            }

            Spacer()

            Text("SWIPE TO BROWSE")
                .font(.system(size: 7, weight: .medium, design: .monospaced))
                .tracking(2)
                .foregroundColor(Color(red: 0.55, green: 0.45, blue: 0.28).opacity(0.55))

            Spacer()

            Button { navigate(backward: false) } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color(red: 0.80, green: 0.65, blue: 0.35))
                    .frame(width: 44, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(red: 0.10, green: 0.08, blue: 0.05).opacity(0.8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(red: 0.50, green: 0.42, blue: 0.28).opacity(0.5), lineWidth: 1)
                            )
                    )
            }
        }
    }

    // MARK: - Disconnected state

    private var disconnectedContent: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("♪")
                .font(.system(size: 42))
                .foregroundColor(Color(red: 0.80, green: 0.62, blue: 0.25).opacity(0.6))

            Text("INSERT COIN")
                .font(.system(size: 18, weight: .black, design: .serif))
                .tracking(5)
                .foregroundStyle(amberGradient)
                .shadow(color: Color(red: 1.0, green: 0.65, blue: 0.10).opacity(0.7), radius: 10)

            Text("CONNECT SPOTIFY TO PLAY WITH MUSIC")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .tracking(2)
                .foregroundColor(Color(red: 0.65, green: 0.52, blue: 0.30).opacity(0.7))
                .multilineTextAlignment(.center)

            Spacer()

            Button(action: onShowSpotify) {
                Text("▶  CONNECT SPOTIFY")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .tracking(2)
                    .foregroundColor(Color(red: 0.08, green: 0.05, blue: 0.02))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(amberGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .shadow(color: Color(red: 1.0, green: 0.65, blue: 0.10).opacity(0.5), radius: 12)
            }
            .padding(.bottom, 4)

            Button(action: onSkip) {
                Text("PLAY WITHOUT MUSIC")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .tracking(2)
                    .foregroundColor(Color(red: 0.60, green: 0.48, blue: 0.28).opacity(0.65))
            }
        }
    }

    // MARK: - Gesture

    private var swipeDragGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onEnded { value in
                if value.translation.height < -30 {
                    navigate(backward: true)
                } else if value.translation.height > 30 {
                    navigate(backward: false)
                }
            }
    }

    private func navigate(backward: Bool) {
        let n = songs.count
        direction = backward ? .backward : .forward
        HapticManager.selection()
        selectedIndex = backward
            ? (selectedIndex - 1 + n) % n
            : (selectedIndex + 1) % n
    }

    // MARK: - Helpers

    private func jukeboxCode(for index: Int) -> String {
        let letter = String(UnicodeScalar(65 + (index / 5))!)
        let digit  = (index % 5) + 1
        return "\(letter)\(digit)"
    }

    private var displayChrome: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: Color(red: 0.88, green: 0.80, blue: 0.60).opacity(0.9), location: 0.00),
                .init(color: Color(red: 0.48, green: 0.42, blue: 0.30).opacity(0.9), location: 0.25),
                .init(color: Color(red: 0.92, green: 0.85, blue: 0.65).opacity(0.9), location: 0.50),
                .init(color: Color(red: 0.52, green: 0.46, blue: 0.32).opacity(0.9), location: 0.75),
                .init(color: Color(red: 0.88, green: 0.80, blue: 0.60).opacity(0.9), location: 1.00),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var amberGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 1.0, green: 0.82, blue: 0.30),
                Color(red: 1.0, green: 0.58, blue: 0.08),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Now Playing Badge

private struct NowPlayingBadge: View {
    let color: Color
    @State private var bar1 = false
    @State private var bar2 = false
    @State private var bar3 = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            bar(height: bar1 ? 10 : 4, delay: 0.0)
            bar(height: bar2 ? 10 : 6, delay: 0.2)
            bar(height: bar3 ? 10 : 3, delay: 0.1)
        }
        .frame(height: 12)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(color.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .onAppear {
            withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true).delay(0.0)) { bar1 = true }
            withAnimation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true).delay(0.2)) { bar2 = true }
            withAnimation(.easeInOut(duration: 0.60).repeatForever(autoreverses: true).delay(0.1)) { bar3 = true }
        }
    }

    private func bar(height: CGFloat, delay: Double) -> some View {
        RoundedRectangle(cornerRadius: 1.5)
            .fill(color)
            .frame(width: 3, height: height)
    }
}
