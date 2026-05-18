import SwiftUI
import SpriteKit

struct FrattypipelineGameView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var scene: FrattypipelineScene

    init(autoplayDemo: Bool = false) {
        let scene = FrattypipelineScene.make()
        scene.autoplayDemo = autoplayDemo
        _scene = StateObject(wrappedValue: scene)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.09, green: 0.11, blue: 0.10),
                    Color(red: 0.03, green: 0.04, blue: 0.04)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            SpriteView(
                scene: scene,
                options: [.ignoresSiblingOrder, .shouldCullNonVisibleNodes]
            )
            .ignoresSafeArea()

            FrattypipelineHUDOverlay(scene: scene)
                .ignoresSafeArea(.container, edges: .top)

            FrattypipelineControlOverlay(input: scene.input)
                .ignoresSafeArea()

            closeButton
        }
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
