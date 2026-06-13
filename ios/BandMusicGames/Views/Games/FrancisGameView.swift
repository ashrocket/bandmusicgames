import SwiftUI
import SpriteKit

// MARK: - Main view

struct FrancisGameView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: SpotifyAuthManager
    @StateObject private var scene = FrancisGameScene.make()

    var body: some View {
        ZStack {
            Color(hex: "#050810").ignoresSafeArea()

            SpriteView(
                scene: scene,
                options: [.ignoresSiblingOrder, .shouldCullNonVisibleNodes]
            )
            .ignoresSafeArea()

            if scene.phase == .pressPlay {
                pressPlayOverlay
            } else if scene.phase == .intro {
                DogIntroView(onDone: { scene.startLevel(1) })
            }

            closeButton
        }
        .onAppear {
            scene.onDismiss = { dismiss() }
            let uri = "spotify:track:64h0585a6LWXOdsCD2pOiW"
            if auth.accessToken != nil, !(auth.isPlaying && auth.currentTrackUri == uri) {
                Task { await auth.playTrack(uri) }
            }
        }
        .onDisappear {
            Task { await auth.pausePlayback() }
        }
    }

    private var pressPlayOverlay: some View {
        VStack(spacing: 10) {
            Spacer()
            Text("Press play to begin")
                .font(.system(size: 22, weight: .light))
                .foregroundColor(.white)
            Text("Francis · Darger")
                .font(.system(size: 13))
                .foregroundColor(Color(hex: "#6d7a94"))
            Spacer().frame(height: 40)
            playButton
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "#050810").opacity(0.8))
        .contentShape(Rectangle())
        .onTapGesture { scene.startIntro() }
    }

    private var playButton: some View {
        Button {
            scene.startIntro()
        } label: {
            ZStack {
                Circle()
                    .fill(Color(hex: "#ffd27a"))
                    .frame(width: 80, height: 80)
                    .shadow(color: Color(hex: "#ffd27a").opacity(0.5), radius: 20)
                Image(systemName: "play.fill")
                    .font(.system(size: 30, weight: .black))
                    .foregroundColor(Color(hex: "#050810"))
                    .offset(x: 3)
            }
        }
        .buttonStyle(.plain)
    }

    private var closeButton: some View {
        VStack {
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(Color.white, Color.black.opacity(0.5))
                        .padding(12)
                }
            }
            Spacer()
        }
    }
}

// MARK: - Dog intro

private struct DogIntroView: View {
    let onDone: () -> Void
    @State private var dogVisible = false
    @State private var thought1 = false
    @State private var thought2 = false
    @State private var thought3 = false
    @State private var done = false

    private func finish() {
        guard !done else { return }
        done = true
        onDone()
    }

    var body: some View {
        ZStack {
            // Dog
            VStack {
                Spacer()
                HStack {
                    dogShape
                        .offset(x: dogVisible ? 0 : -300)
                        .animation(.spring(duration: 0.9, bounce: 0.2), value: dogVisible)
                    Spacer()
                }
                .padding(.bottom, 120)
            }

            // Thought bubbles
            VStack {
                Spacer()
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        if thought1 {
                            ThoughtBubble(text: "stars will appear")
                                .transition(.asymmetric(insertion: .scale.combined(with: .opacity),
                                                         removal: .opacity))
                        }
                        if thought2 {
                            ThoughtBubble(text: "a constellation will blink")
                                .transition(.asymmetric(insertion: .scale.combined(with: .opacity),
                                                         removal: .opacity))
                        }
                        if thought3 {
                            ThoughtBubble(text: "drag between stars to match it")
                                .transition(.asymmetric(insertion: .scale.combined(with: .opacity),
                                                         removal: .opacity))
                        }
                    }
                    .padding(.leading, 100)
                    Spacer()
                }
                .padding(.bottom, 160)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { finish() }
        .onAppear { runSequence() }
    }

    private var dogShape: some View {
        Image(systemName: "dog.fill")
            .font(.system(size: 72))
            .foregroundStyle(
                LinearGradient(colors: [Color(hex: "#ffd27a"), Color(hex: "#f5b461")],
                               startPoint: .top, endPoint: .bottom)
            )
            .shadow(color: Color(hex: "#ffd27a").opacity(0.3), radius: 10)
            .padding(.leading, 24)
    }

    private func runSequence() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation { dogVisible = true }
        }
        show("thought1", at: 1.4, hide: 3.4)
        show("thought2", at: 3.6, hide: 5.6)
        show("thought3", at: 5.8, hide: 8.3)
    }

    private func show(_ name: String, at showTime: Double, hide: Double) {
        DispatchQueue.main.asyncAfter(deadline: .now() + showTime) {
            withAnimation(.easeOut(duration: 0.4)) {
                switch name {
                case "thought1": thought1 = true
                case "thought2": thought2 = true
                default:         thought3 = true
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + hide) {
            withAnimation(.easeIn(duration: 0.3)) {
                switch name {
                case "thought1": thought1 = false
                case "thought2": thought2 = false
                default:         thought3 = false
                }
            }
        }
        if name == "thought3" {
            DispatchQueue.main.asyncAfter(deadline: .now() + hide + 0.5) {
                finish()
            }
        }
    }
}

private struct ThoughtBubble: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(Color(hex: "#1a1408"))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(hex: "#ffd27a").opacity(0.95))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color(hex: "#ffd27a").opacity(0.2), radius: 8)
    }
}
