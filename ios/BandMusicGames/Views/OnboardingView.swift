import SwiftUI
import MusicKit

/// First-run music source picker. Apple Music is the recommended path;
/// Spotify hands off to the existing SpotifySheetView; skip plays without music.
struct OnboardingView: View {
    enum Choice {
        case appleMusic
        case spotify
        case skip
    }

    @EnvironmentObject private var appleMusic: AppleMusicManager

    let onComplete: (Choice) -> Void

    @State private var isActivating = false
    @State private var notice: Notice? = nil

    private struct Notice {
        let title: String
        let message: String
        let showsSettingsLink: Bool
    }

    var body: some View {
        GeometryReader { geo in
            let compact = geo.size.height < 500

            ZStack {
                Color(hex: "#06070B").ignoresSafeArea()

                RadialGradient(
                    colors: [Color(hex: "#FA243C").opacity(0.14), Color.clear],
                    center: .top,
                    startRadius: 0,
                    endRadius: 480
                )
                .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: compact ? 14 : 22) {
                        VStack(spacing: compact ? 4 : 8) {
                            Text("BAND MUSIC GAMES")
                                .font(.system(size: compact ? 24 : 30, weight: .black, design: .monospaced))
                                .tracking(3)
                                .foregroundColor(.white)
                                .shadow(color: Color(hex: "#FF1493").opacity(0.5), radius: 12)

                            Text("EVERY GAME HAS A SOUNDTRACK.\nPICK WHERE YOURS PLAYS FROM.")
                                .font(.system(size: compact ? 10 : 11, weight: .bold, design: .monospaced))
                                .tracking(1.5)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .padding(.top, geo.safeAreaInsets.top + (compact ? 16 : 40))

                        VStack(spacing: compact ? 10 : 14) {
                            sourceCard(
                                icon: "applelogo",
                                title: "APPLE MUSIC",
                                subtitle: "Recommended — plays instantly in-app",
                                hue: Color(hex: "#FA243C"),
                                badge: "SMOOTHEST",
                                busy: isActivating,
                                compact: compact
                            ) {
                                activateAppleMusic()
                            }

                            sourceCard(
                                icon: "music.note",
                                title: "SPOTIFY",
                                subtitle: "Connect your Spotify Premium account",
                                hue: Color(red: 0.11, green: 0.73, blue: 0.33),
                                badge: nil,
                                busy: false,
                                compact: compact
                            ) {
                                HapticManager.impact(.medium)
                                onComplete(.spotify)
                            }
                        }
                        .frame(maxWidth: 430)

                        if let notice {
                            noticeCard(notice, compact: compact)
                                .frame(maxWidth: 430)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }

                        Button {
                            HapticManager.selection()
                            onComplete(.skip)
                        } label: {
                            Text("SKIP FOR NOW — PLAY WITHOUT MUSIC")
                                .font(.system(size: compact ? 9 : 10, weight: .bold, design: .monospaced))
                                .tracking(1.5)
                                .foregroundColor(.white.opacity(0.4))
                                .padding(.vertical, 12)
                        }
                        .padding(.bottom, geo.safeAreaInsets.bottom + (compact ? 10 : 24))
                    }
                    .padding(.horizontal, 24)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .ignoresSafeArea()
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: notice?.title)
    }

    // MARK: - Actions

    private func activateAppleMusic() {
        guard !isActivating else { return }
        HapticManager.impact(.medium)
        isActivating = true
        notice = nil
        Task { @MainActor in
            let result = await appleMusic.activateAsPreferred()
            isActivating = false
            switch result {
            case .activated:
                HapticManager.notification(.success)
                onComplete(.appleMusic)
            case .denied:
                HapticManager.notification(.error)
                notice = Notice(
                    title: "APPLE MUSIC ACCESS DENIED",
                    message: "Allow music access in Settings, or pick another source.",
                    showsSettingsLink: true
                )
            case .noSubscription:
                HapticManager.notification(.warning)
                notice = Notice(
                    title: "NO ACTIVE SUBSCRIPTION",
                    message: "This device has no Apple Music subscription. Connect Spotify or play without music.",
                    showsSettingsLink: false
                )
            }
        }
    }

    // MARK: - Pieces

    private func sourceCard(
        icon: String,
        title: String,
        subtitle: String,
        hue: Color,
        badge: String?,
        busy: Bool,
        compact: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: compact ? 20 : 24, weight: .bold))
                    .foregroundColor(hue)
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.system(size: compact ? 14 : 16, weight: .black, design: .monospaced))
                            .tracking(1.5)
                            .foregroundColor(.white)
                        if let badge {
                            Text(badge)
                                .font(.system(size: 8, weight: .black, design: .monospaced))
                                .tracking(1)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(hue.opacity(0.22))
                                .foregroundColor(hue)
                                .clipShape(Capsule())
                        }
                    }
                    Text(subtitle)
                        .font(.system(size: compact ? 9 : 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.55))
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                if busy {
                    ProgressView()
                        .tint(hue)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(hue.opacity(0.7))
                }
            }
            .padding(compact ? 14 : 18)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(hue.opacity(0.09))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(hue.opacity(0.55), lineWidth: 1.5)
            )
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .disabled(busy)
    }

    private func noticeCard(_ notice: Notice, compact: Bool) -> some View {
        VStack(spacing: 8) {
            Text(notice.title)
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .tracking(1.5)
                .foregroundColor(.orange)
            Text(notice.message)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.7))
            if notice.showsSettingsLink {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("OPEN SETTINGS")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.1))
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
                .padding(.top, 2)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.orange.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.orange.opacity(0.35), lineWidth: 1)
        )
    }
}

#Preview {
    OnboardingView(onComplete: { _ in })
        .environmentObject(AppleMusicManager())
}
