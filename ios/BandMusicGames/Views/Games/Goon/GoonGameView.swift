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
            switch scene.phase {
            case .playing:
                GoonHUDOverlay(scene: scene)
                    .ignoresSafeArea(.container, edges: .bottom)
                GoonControlOverlay(input: scene.input)
                    .ignoresSafeArea()
            case .levelComplete:
                GoonLevelCompleteCard(level: scene.levelNum) { scene.nextLevel() }
            case .gameOver:
                GoonGameOverCard(
                    onRetry: { scene.retry() },
                    onMenu:  { scene.resetAndReturnToTitle() }
                )
            case .win:
                GoonWinCard { scene.replayFromWin() }
            case .title:
                EmptyView()
            }
            closeButton
        }
        .onAppear {
            scene.activate()
            scene.startLevel(launchLevel)
        }
        .onDisappear { scene.deactivate() }
    }

    private var launchLevel: Int {
#if DEBUG
        if let debugLevel = debugLaunchLevel {
            return debugLevel
        }
#endif
        return GoonGameScene.savedLevel
    }

#if DEBUG
    private var debugLaunchLevel: Int? {
        let args = ProcessInfo.processInfo.arguments
        if let index = args.firstIndex(of: "-bmg-goon-level"),
           args.indices.contains(index + 1),
           let level = Int(args[index + 1]) {
            return level
        }

        for arg in args {
            if arg.hasPrefix("-bmg-goon-level="),
               let level = Int(arg.replacingOccurrences(of: "-bmg-goon-level=", with: "")) {
                return level
            }
        }

        return nil
    }
#endif

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
