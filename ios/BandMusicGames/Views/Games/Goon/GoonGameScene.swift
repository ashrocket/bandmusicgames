import SpriteKit

@MainActor
final class GoonGameScene: SKScene, ObservableObject {
    static func make() -> GoonGameScene {
        let scene = GoonGameScene(size: CGSize(width: 800, height: 600))
        scene.scaleMode = .aspectFit
        scene.backgroundColor = SKColor(red: 0.04, green: 0.10, blue: 0.04, alpha: 1)
        return scene
    }

    func activate() {
        // Audio + music will be wired in later tasks
    }

    func deactivate() {
        // Teardown
    }
}
