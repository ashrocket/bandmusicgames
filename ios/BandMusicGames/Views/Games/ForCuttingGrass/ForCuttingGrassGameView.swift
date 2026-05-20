import SwiftUI
import SpriteKit

struct ForCuttingGrassGameView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: SpotifyAuthManager
    @StateObject private var scene = ForCuttingGrassGameScene.make()
    @State private var canvasZoom: CGFloat = 1

    var body: some View {
        ZStack {
            Color(hex: "#0a1a0a").ignoresSafeArea()

            SpriteView(
                scene: scene,
                options: [.ignoresSiblingOrder, .shouldCullNonVisibleNodes]
            )
            .scaleEffect(canvasZoom, anchor: .center)
            .gesture(canvasZoomGesture)
            .ignoresSafeArea()

            if scene.phase == .playing {
                ForCuttingGrassControlOverlay(input: scene.input)
                    .ignoresSafeArea()

                hud
                    .allowsHitTesting(false)
            } else {
                phaseOverlay
            }

            closeButton
        }
        .onAppear { scene.activate() }
        .onDisappear { scene.deactivate() }
    }

    private var canvasZoomGesture: some Gesture {
        MagnificationGesture(minimumScaleDelta: 0.01)
            .onChanged { value in
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    canvasZoom = max(1, min(2.2, value))
                }
            }
            .onEnded { _ in
                withAnimation(.spring(response: 0.22, dampingFraction: 0.82)) {
                    canvasZoom = 1
                }
            }
    }

    private var hud: some View {
        GeometryReader { geo in
            let playfield = ForCuttingGrassPlayfieldLayout.swiftUIFrame(in: geo.size)

            VStack {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("LEVEL \(scene.levelNum)")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.6))
                        Text(scene.config.sub)
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("SCORE")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.6))
                        Text("\(scene.score)")
                            .font(.system(size: 20, weight: .black, design: .monospaced))
                            .foregroundColor(Color(hex: "#ffd27a"))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, playfield.minY + 12)

                HStack(spacing: 10) {
                    Text(gasLabel)
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundColor(Color(hex: "#ffd27a"))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.black.opacity(0.35)))

                    if scene.config.usesGas {
                        GeometryReader { g in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.black.opacity(0.35))
                                Capsule()
                                    .fill(gasColor)
                                    .frame(width: g.size.width * gasRatio)
                            }
                        }
                        .frame(height: 8)
                    }

                    Text("TRIES \(scene.triesRemaining)")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundColor(Color(hex: "#ffd27a"))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.black.opacity(0.35)))
                }
                .padding(.horizontal, 24)
                .padding(.top, 4)

                Spacer()
            }
        }
    }

    private var gasLabel: String {
        scene.config.usesGas ? "GAS \(Int(round(gasRatio * 100)))%" : "GAS INF"
    }

    private var gasRatio: CGFloat {
        guard scene.config.gasMax > 0 else { return 0 }
        return max(0, min(1, scene.gas / scene.config.gasMax))
    }

    private var gasColor: Color {
        if gasRatio < 0.2 { return .red }
        if gasRatio < 0.5 { return .orange }
        return Color(hex: "#ffd27a")
    }

    private var phaseOverlay: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()

            VStack(spacing: 24) {
                if scene.phase == .levelComplete {
                    Text("LEVEL COMPLETE")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundColor(.white)

                    Button("NEXT LEVEL") {
                        scene.nextLevel()
                    }
                    .buttonStyle(ForCuttingGrassButtonStyle())
                } else if scene.phase == .gameOver {
                    Text(scene.gameOverTitle)
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundColor(.red)

                    Button("RETRY") {
                        scene.retry()
                    }
                    .buttonStyle(ForCuttingGrassButtonStyle())
                } else if scene.phase == .win {
                    Text("YOU WON!")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundColor(Color(hex: "#ffd27a"))

                    Button("PLAY AGAIN") {
                        scene.replayFromWin()
                    }
                    .buttonStyle(ForCuttingGrassButtonStyle())
                }
            }
        }
    }

    private var closeButton: some View {
        GeometryReader { geo in
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Color.white, Color.black.opacity(0.5))
                    .padding(12)
            }
            .position(x: geo.size.width - 32, y: geo.safeAreaInsets.top + 18)
        }
        .ignoresSafeArea()
    }
}

struct ForCuttingGrassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 18, weight: .bold, design: .monospaced))
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
            .background(Color(hex: "#ffd27a"))
            .foregroundColor(.black)
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}
