import SpriteKit
import Combine

enum GoonPhase {
    case title
    case playing
    case levelComplete
    case gameOver
    case win
}

@MainActor
final class GoonGameScene: SKScene, ObservableObject {

    // MARK: - Phase state (observed by SwiftUI overlays)
    @Published private(set) var phase: GoonPhase = .title

    // MARK: - Level state
    private(set) var levelNum: Int = 1
    var config: GoonLevelConfig { GoonLevels.all[levelNum - 1] }

    // MARK: - Runtime state
    var gas: CGFloat = 0
    var grid = GoonGrid(cells: ContiguousArray<GoonTile>(repeating: .tall, count: GoonGrid.width * GoonGrid.height))
    var score: Int = 0

    /// Test hook — when non-nil, used in place of grid.cutPercentage by tickGameLogic.
    var cutPctOverride: Double?

    // MARK: - Construction
    static func make() -> GoonGameScene {
        let scene = GoonGameScene(size: CGSize(width: 800, height: 600))
        scene.scaleMode = .aspectFit
        scene.backgroundColor = SKColor(red: 0.04, green: 0.10, blue: 0.04, alpha: 1)
        return scene
    }

    // MARK: - Transitions
    func startLevel(_ n: Int) {
        levelNum = max(1, min(n, GoonLevels.all.count))
        grid = GoonGrid.make(for: config)
        gas = config.gasMax
        cutPctOverride = nil
        phase = .playing
    }

    func retry() {
        startLevel(levelNum)
    }

    func nextLevel() {
        if levelNum >= GoonLevels.all.count {
            phase = .win
        } else {
            startLevel(levelNum + 1)
        }
    }

    func resetAndReturnToTitle() {
        levelNum = 1
        score = 0
        phase = .title
    }

    func tickGameLogic(deltaSeconds: CGFloat) {
        guard phase == .playing else { return }
        if gas <= 0 {
            phase = .gameOver
            return
        }
        let pct = cutPctOverride ?? grid.cutPercentage
        if pct >= Double(config.win) {
            phase = (levelNum >= GoonLevels.all.count) ? .win : .levelComplete
        }
    }

    // MARK: - Lifecycle
    func activate() {}
    func deactivate() {}

    // MARK: - SpriteKit update loop
    override func update(_ currentTime: TimeInterval) {
        let dt = lastUpdate.map { CGFloat(currentTime - $0) } ?? 0.016
        lastUpdate = currentTime
        tickGameLogic(deltaSeconds: dt)
    }
    private var lastUpdate: TimeInterval?
}
