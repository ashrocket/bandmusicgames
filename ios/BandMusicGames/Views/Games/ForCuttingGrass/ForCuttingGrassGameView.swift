import SwiftUI
import SpriteKit

struct ForCuttingGrassGameView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: SpotifyAuthManager
    @StateObject private var scene = ForCuttingGrassGameScene.make()
    @State private var canvasZoom: CGFloat = 1

    var body: some View {
        VStack(spacing: 0) {
            if scene.phase == .playing {
                hud
            }

            ZStack {
                SpriteView(
                    scene: scene,
                    options: [.ignoresSiblingOrder, .shouldCullNonVisibleNodes]
                )
                .scaleEffect(canvasZoom, anchor: .center)
                .gesture(canvasZoomGesture)

                if scene.phase != .playing {
                    phaseOverlay
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if scene.phase == .playing {
                ForCuttingGrassControlOverlay(input: scene.input)
            }
        }
        .background(Color(hex: "#0a1a0a").ignoresSafeArea())
        .overlay(alignment: .topTrailing) { closeButton }
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
        HStack(spacing: 8) {
                // Level Block
                hudBlock {
                    VStack(spacing: 2) {
                        Text("LEVEL")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white.opacity(0.5))
                        HStack(spacing: 4) {
                            Image(systemName: "laurel.leading")
                                .font(.system(size: 14))
                            Text("\(scene.levelNum)")
                                .font(.system(size: 22, weight: .black, design: .rounded))
                            Image(systemName: "laurel.trailing")
                                .font(.system(size: 14))
                        }
                        .foregroundColor(Color(hex: "#ffd27a"))
                    }
                }
                
                // Progress Block
                hudBlock {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("PROGRESS")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white.opacity(0.5))
                            Spacer()
                            Text("\(Int(scene.grid.cutPercentage * 100))%")
                                .font(.system(size: 18, weight: .black, design: .monospaced))
                                .foregroundColor(Color(hex: "#8bc44a"))
                                .shadow(color: Color(hex: "#8bc44a").opacity(0.5), radius: 4)
                        }
                        // Progress Bar (Segmented Look)
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.black.opacity(0.4)).frame(height: 10)
                            Capsule()
                                .fill(
                                    LinearGradient(colors: [Color(hex: "#8bc44a"), Color(hex: "#a6f0a6")],
                                                   startPoint: .leading, endPoint: .trailing)
                                )
                                .frame(width: max(0, 100 * scene.grid.cutPercentage), height: 10)
                                .shadow(color: Color(hex: "#8bc44a").opacity(0.4), radius: 5)
                            
                            // Segments
                            HStack(spacing: 8) {
                                ForEach(0..<10) { _ in
                                    Rectangle().fill(Color.black.opacity(0.2)).frame(width: 2, height: 10)
                                }
                            }
                        }
                        .frame(width: 100)
                        .clipShape(Capsule())
                    }
                }
                .frame(width: 130)

                // Status Block (Gas & Tries)
                hudBlock {
                    HStack(spacing: 12) {
                        if scene.config.usesGas || true { // Force showing for mockup parity if needed
                            VStack(spacing: 2) {
                                Image(systemName: "fuelpump.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.red)
                                Text(scene.config.usesGas ? "GAS" : "GAS INF")
                                    .font(.system(size: 7, weight: .bold))
                                if scene.config.usesGas {
                                    Text("\(Int(gasRatio * 100))%")
                                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                                        .foregroundColor(gasColor)
                                } else {
                                    Text("∞")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                        
                        VStack(spacing: 2) {
                            Image(systemName: "leaf.fill")
                                .font(.system(size: 10))
                                .foregroundColor(Color(hex: "#8bc44a"))
                            Text("TRIES")
                                .font(.system(size: 7, weight: .bold))
                            Text("\(scene.triesRemaining)")
                                .font(.system(size: 16, weight: .bold))
                        }
                    }
                    .foregroundColor(.white)
                }

                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .background(
                Rectangle()
                    .fill(Color.black.opacity(0.55))
            )
    }
    
    private func hudBlock<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.05), lineWidth: 1))
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
        Button { dismiss() } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 28))
                .symbolRenderingMode(.palette)
                .foregroundStyle(Color.white, Color.black.opacity(0.5))
                .padding(10)
        }
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
