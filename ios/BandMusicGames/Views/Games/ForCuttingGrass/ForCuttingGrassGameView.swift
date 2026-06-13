import SwiftUI
import SpriteKit

struct ForCuttingGrassGameView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: SpotifyAuthManager
    @StateObject private var scene = ForCuttingGrassGameScene.make()
    @State private var canvasZoom: CGFloat = 1
    @State private var controlsMenuOpen = false

    var body: some View {
        ZStack(alignment: .top) {
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
                    .onTapGesture {
                        if controlsMenuOpen {
                            withAnimation(.easeOut(duration: 0.16)) {
                                controlsMenuOpen = false
                            }
                        }
                    }

                    if scene.phase != .playing {
                        phaseOverlay
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if scene.phase == .playing {
                    ForCuttingGrassControlOverlay(input: scene.input)
                }
            }

            if scene.phase == .playing && controlsMenuOpen {
                ControlsDropdownPanel(input: scene.input, isPresented: $controlsMenuOpen)
                    .padding(.horizontal, 14)
                    .padding(.top, 58)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(2)
            }
        }
        .background(Color(hex: "#0a1a0a").ignoresSafeArea())
        .onAppear {
            scene.activate()
            let uri = "spotify:track:6EJAb3oTjDFwrt1dpIJPbr"
            if auth.accessToken != nil, !(auth.isPlaying && auth.currentTrackUri == uri) {
                Task { await auth.playTrack(uri) }
            }
        }
        .onDisappear {
            scene.deactivate()
            Task { await auth.pausePlayback() }
        }
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
        HStack(spacing: 3) {
            hudBlock {
                VStack(spacing: 1) {
                    Text("LEVEL")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(.white.opacity(0.52))
                    HStack(spacing: 2) {
                        Image(systemName: "laurel.leading")
                            .font(.system(size: 9, weight: .bold))
                        Text("\(scene.levelNum)")
                            .font(.system(size: 17, weight: .black, design: .rounded))
                        Image(systemName: "laurel.trailing")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundColor(Color(hex: "#ffd27a"))
                }
            }
            .frame(width: 48, height: 44)

            hudBlock {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text("PROGRESS")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(.white.opacity(0.52))
                        Spacer(minLength: 2)
                        Text("\(Int(scene.grid.cutPercentage * 100))%")
                            .font(.system(size: 15, weight: .black, design: .monospaced))
                            .foregroundColor(Color(hex: "#8bc44a"))
                            .shadow(color: Color(hex: "#8bc44a").opacity(0.45), radius: 4)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.black.opacity(0.42))
                            if scene.grid.cutPercentage > 0 {
                                Capsule()
                                    .fill(Color(hex: "#8bc44a"))
                                    .frame(width: max(4, geo.size.width * CGFloat(scene.grid.cutPercentage)))
                            }
                        }
                    }
                    .frame(height: 5)
                    .clipShape(Capsule())
                }
            }
            .frame(minWidth: 66, maxWidth: .infinity, minHeight: 44, maxHeight: 44)
            .layoutPriority(1)

            hudBlock {
                VStack(spacing: 1) {
                    Image(systemName: "fuelpump.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.red)
                    Text(scene.config.usesGas ? "GAS" : "GAS INF")
                        .font(.system(size: 6.5, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                    Text(scene.config.usesGas ? "\(Int(gasRatio * 100))%" : "∞")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundColor(scene.config.usesGas ? gasColor : .orange)
                }
            }
            .frame(width: 40, height: 44)

            hudBlock {
                VStack(spacing: 1) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Color(hex: "#8bc44a"))
                    Text("TRIES")
                        .font(.system(size: 6.5, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                    Text("\(scene.triesRemaining)")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                }
            }
            .frame(width: 38, height: 44)

            ControlsDropdownButton(input: scene.input, isPresented: $controlsMenuOpen)
                .frame(width: 58, height: 44)

            hudCloseButton
                .frame(width: 30, height: 44)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .background(Rectangle().fill(Color.black.opacity(0.62)))
    }
    
    private func hudBlock<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 5)
            .padding(.vertical, 5)
            .background(Color.black.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.white.opacity(0.08), lineWidth: 1))
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
        ZStack(alignment: .topTrailing) {
            Color.black.opacity(0.6).ignoresSafeArea()

            VStack(spacing: 24) {
                if scene.phase == .levelComplete {
                    let nextIdx = scene.levelNum  // levelNum is 1-indexed; after completion next = levelNum
                    let nextConfig = nextIdx < ForCuttingGrassLevels.all.count
                        ? ForCuttingGrassLevels.all[nextIdx] : nil

                    Text("LEVEL COMPLETE")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundColor(.white)

                    if let next = nextConfig {
                        VStack(spacing: 6) {
                            Text("NEXT UP")
                                .font(.system(size: 10, weight: .black, design: .monospaced))
                                .tracking(2.5)
                                .foregroundColor(Color(hex: "#8bc44a").opacity(0.8))
                            Text(next.sub.uppercased())
                                .font(.system(size: 15, weight: .black, design: .monospaced))
                                .foregroundColor(.white)
                            Text(next.desc)
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .multilineTextAlignment(.center)
                                .foregroundColor(.white.opacity(0.55))
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    Button("NEXT LEVEL") {
                        scene.nextLevel()
                    }
                    .buttonStyle(ForCuttingGrassButtonStyle())
                } else if scene.phase == .gameOver {
                    Text(scene.gameOverTitle)
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundColor(.red)

                    Text("\(Int(scene.grid.cutPercentage * 100))% mowed")
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))

                    Button("RETRY") {
                        scene.retry()
                    }
                    .buttonStyle(ForCuttingGrassButtonStyle())
                } else if scene.phase == .win {
                    Text("YOU WON!")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundColor(Color(hex: "#ffd27a"))

                    Text("ALL 5 YARDS MOWED")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .tracking(2)
                        .foregroundColor(.white.opacity(0.52))

                    Button("PLAY AGAIN") {
                        scene.replayFromWin()
                    }
                    .buttonStyle(ForCuttingGrassButtonStyle())
                }

                Button("QUIT") { dismiss() }
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.52))
            }

            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Color.white, Color.black.opacity(0.5))
                    .padding(16)
            }
        }
    }

    private var hudCloseButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "xmark")
                .font(.system(size: 17, weight: .black))
                .foregroundColor(.white.opacity(0.9))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close")
    }
}

private struct ControlsDropdownButton: View {
    @ObservedObject var input: ForCuttingGrassInputController
    @Binding var isPresented: Bool

    var body: some View {
        Button {
            withAnimation(.easeOut(duration: 0.16)) {
                isPresented.toggle()
            }
        } label: {
            VStack(spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: input.controlStyle.symbolName)
                        .font(.system(size: 11, weight: .black))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .black))
                        .rotationEffect(.degrees(isPresented ? 180 : 0))
                }
                Text("CONTROLS")
                    .font(.system(size: 6.2, weight: .black, design: .monospaced))
            }
            .foregroundColor(Color(hex: "#ffd27a"))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(isPresented ? Color(hex: "#ffd27a").opacity(0.82) : Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Controls")
    }
}

private struct ControlsDropdownPanel: View {
    @ObservedObject var input: ForCuttingGrassInputController
    @Binding var isPresented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("CHOOSE INPUT")
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundColor(.white.opacity(0.56))
                .tracking(1.2)
                .padding(.horizontal, 12)
                .padding(.top, 11)
                .padding(.bottom, 4)

            ForEach(ForCuttingGrassControlStyle.allCases) { candidate in
                ControlMenuRow(
                    style: candidate,
                    selected: input.controlStyle == candidate
                ) {
                    withAnimation(.easeOut(duration: 0.14)) {
                        input.controlStyle = candidate
                        isPresented = false
                    }
                }
            }
        }
        .padding(5)
        .frame(maxWidth: 330)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color(hex: "#06160a").opacity(0.96))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(Color(hex: "#ffd27a").opacity(0.62), lineWidth: 1.2)
        )
        .shadow(color: .black.opacity(0.38), radius: 16, y: 8)
    }
}

private struct ControlMenuRow: View {
    let style: ForCuttingGrassControlStyle
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(selected ? Color(hex: "#ffd27a").opacity(0.18) : Color.white.opacity(0.035))
                        .overlay(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .stroke(selected ? Color(hex: "#ffd27a").opacity(0.62) : Color.white.opacity(0.1), lineWidth: 1)
                        )

                    Image(systemName: style.symbolName)
                        .font(.system(size: 15, weight: .black))
                        .foregroundColor(selected ? Color(hex: "#ffd27a") : .white.opacity(0.58))
                }
                .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 3) {
                    Text(style.title.uppercased())
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundColor(selected ? Color(hex: "#ffd27a") : .white.opacity(0.82))
                    Text(style.subtitle)
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.55))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                Spacer(minLength: 8)

                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .black))
                        .foregroundColor(Color(hex: "#ffd27a"))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
