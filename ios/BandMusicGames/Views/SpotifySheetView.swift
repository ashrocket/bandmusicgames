import SwiftUI

/// Presented when the user needs to connect (or skip) Spotify before playing.
/// Matches the jukebox aesthetic: dark mahogany, amber accents, chrome buttons.
struct SpotifySheetView: View {
    @EnvironmentObject private var auth: SpotifyAuthManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color(red: 0.10, green: 0.06, blue: 0.03)
                .ignoresSafeArea()

            // Background amber glow
            RadialGradient(
                colors: [
                    Color(red: 1.0, green: 0.60, blue: 0.08).opacity(0.18),
                    Color.clear,
                ],
                center: .top,
                startRadius: 0,
                endRadius: 300
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Grab handle
                Capsule()
                    .fill(Color(red: 0.45, green: 0.35, blue: 0.20).opacity(0.6))
                    .frame(width: 36, height: 4)
                    .padding(.top, 10)
                    .padding(.bottom, 24)

                // Coin slot icon
                Text("🎵")
                    .font(.system(size: 52))
                    .shadow(color: Color(red: 1.0, green: 0.65, blue: 0.10).opacity(0.8), radius: 20)
                    .padding(.bottom, 20)

                Text("INSERT COIN")
                    .font(.system(size: 28, weight: .black, design: .serif))
                    .tracking(6)
                    .foregroundStyle(amberGradient)
                    .shadow(color: Color(red: 1.0, green: 0.65, blue: 0.10).opacity(0.7), radius: 14)
                    .padding(.bottom, 8)

                Text("CONNECT SPOTIFY TO PLAY WITH MUSIC")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .tracking(3)
                    .multilineTextAlignment(.center)
                    .foregroundColor(Color(red: 0.70, green: 0.55, blue: 0.32).opacity(0.75))
                    .padding(.horizontal, 32)
                    .padding(.bottom, 40)

                // Connect button
                Button {
                    auth.login()
                } label: {
                    HStack(spacing: 10) {
                        if auth.isLoading {
                            ProgressView()
                                .tint(Color(red: 0.08, green: 0.05, blue: 0.02))
                        } else {
                            Image(systemName: "music.note")
                                .font(.system(size: 16, weight: .bold))
                        }
                        Text(auth.isLoading ? "CONNECTING..." : "▶  CONNECT SPOTIFY")
                            .font(.system(size: 14, weight: .black, design: .monospaced))
                            .tracking(2)
                    }
                    .foregroundColor(Color(red: 0.08, green: 0.05, blue: 0.02))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(amberGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color(red: 0.95, green: 0.75, blue: 0.35).opacity(0.6), lineWidth: 1.5)
                    )
                    .shadow(color: Color(red: 1.0, green: 0.65, blue: 0.10).opacity(0.45), radius: 14, y: 4)
                }
                .disabled(auth.isLoading)
                .padding(.horizontal, 28)
                .padding(.bottom, 14)

                // Skip button
                Button {
                    auth.skipSpotify()
                    dismiss()
                } label: {
                    Text("PLAY WITHOUT MUSIC")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .tracking(2)
                        .foregroundColor(Color(red: 0.55, green: 0.44, blue: 0.25).opacity(0.70))
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color(red: 0.42, green: 0.32, blue: 0.18).opacity(0.45), lineWidth: 1.5)
                        )
                }
                .padding(.horizontal, 28)

                Spacer()

                Text("Spotify is a trademark of Spotify AB")
                    .font(.system(size: 9))
                    .foregroundColor(Color(red: 0.45, green: 0.35, blue: 0.20).opacity(0.5))
                    .padding(.bottom, 24)
            }
        }
        .onChange(of: auth.isConnected) { connected in
            if connected { dismiss() }
        }
    }

    private var amberGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 1.0, green: 0.84, blue: 0.30),
                Color(red: 1.0, green: 0.58, blue: 0.08),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

#Preview {
    SpotifySheetView()
        .environmentObject(SpotifyAuthManager())
}
