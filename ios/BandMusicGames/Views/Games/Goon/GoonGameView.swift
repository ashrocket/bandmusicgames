import SwiftUI
import SpriteKit

struct GoonGameView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: SpotifyAuthManager
    @StateObject private var scene = GoonGameScene.make()

    var body: some View {
        ZStack {
            Color(hex: "#0a1a0a").ignoresSafeArea()
            SpriteView(
                scene: scene,
                options: [.ignoresSiblingOrder, .shouldCullNonVisibleNodes]
            )
            .ignoresSafeArea()
            if scene.phase == .playing {
                GoonControlOverlay(input: scene.input)
                    .ignoresSafeArea()
            }
            closeButton
        }
        .onAppear {
            scene.activate()
            scene.startLevel(GoonGameScene.savedLevel)
        }
        .onDisappear { scene.deactivate() }
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
