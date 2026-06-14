import SwiftUI

/// Compact in-game banner shown when Spotify playback fails.
/// Add via .spotifyErrorBanner() on any fullScreenCover game view.
struct SpotifyErrorBanner: View {
    @EnvironmentObject private var auth: SpotifyAuthManager
    let error: SpotifyAuthManager.PlaybackError

    var body: some View {
        VStack {
            Spacer()
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.orange)

                Text(error.message)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: 0)

                if case .noDevice = error {
                    Button {
                        auth.wakeSpotify()
                        auth.playbackError = nil
                        Task {
                            try? await Task.sleep(nanoseconds: 4_000_000_000)
                            await auth.fetchPlaybackState()
                            if !auth.isPlaying { await auth.retryLastPlayback() }
                        }
                    } label: {
                        Text("OPEN")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(red: 0.11, green: 0.73, blue: 0.33))
                            .foregroundColor(.black)
                            .clipShape(Capsule())
                    }
                }
                if case .notPremium = error, let uri = auth.lastAttemptedUri,
                   let url = URL(string: uri) {
                    Button {
                        UIApplication.shared.open(url)
                        auth.playbackError = nil
                    } label: {
                        Text("OPEN IN SPOTIFY")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Color(red: 0.11, green: 0.73, blue: 0.33))
                            .foregroundColor(.black)
                            .clipShape(Capsule())
                    }
                }

                Button { auth.playbackError = nil } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white.opacity(0.55))
                        .padding(4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 14)
            .background(
                Color.black.opacity(0.88)
                    .overlay(
                        Rectangle()
                            .fill(Color.orange.opacity(0.65))
                            .frame(height: 2),
                        alignment: .top
                    )
            )
        }
        .ignoresSafeArea(edges: .bottom)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

private struct SpotifyErrorBannerModifier: ViewModifier {
    @EnvironmentObject private var auth: SpotifyAuthManager

    func body(content: Content) -> some View {
        ZStack(alignment: .bottom) {
            content
            if let error = auth.playbackError {
                SpotifyErrorBanner(error: error)
                    .zIndex(200)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.78), value: auth.playbackError != nil)
    }
}

extension View {
    func spotifyErrorBanner() -> some View {
        modifier(SpotifyErrorBannerModifier())
    }
}
