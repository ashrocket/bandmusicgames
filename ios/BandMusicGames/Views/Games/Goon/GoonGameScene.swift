import SpriteKit
import Combine

enum GoonPhase {
    case title
    case playing
    case levelComplete
    case gameOver
    case win
}

struct GoonMower {
    var position: CGPoint
    var velocity: CGVector
    var facing: CGFloat    // radians
}

@MainActor
final class GoonGameScene: SKScene, ObservableObject {

    // MARK: - Constants
    private static let mowerSpeed: CGFloat = 220  // points per second
    private static let mowerSize = CGSize(width: 56, height: 56)

    // MARK: - Phase state (observed by SwiftUI overlays)
    @Published private(set) var phase: GoonPhase = .title

    // MARK: - Level state
    private(set) var levelNum: Int = 1
    var config: GoonLevelConfig { GoonLevels.all[levelNum - 1] }

    // MARK: - Runtime state
    var gas: CGFloat = 0
    var grid = GoonGrid(cells: ContiguousArray<GoonTile>(repeating: .tall, count: GoonGrid.width * GoonGrid.height))
    var score: Int = 0
    var mower: GoonMower = GoonMower(position: .zero, velocity: .zero, facing: 0)
    var input: GoonInputController = GoonInputController()
    private var mowerNode: SKNode?

    /// Test hook — when non-nil, used in place of grid.cutPercentage by tickGameLogic.
    var cutPctOverride: Double?

    // MARK: - Render layers
    private let gridLayer = SKNode()

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
        input.reset()
        input.canDig = config.stumps > 0
        mower.position = CGPoint(x: size.width / 2, y: size.height / 2)
        mower.velocity = .zero
        mower.facing = 0
        phase = .playing
        drawGrid()
        placeMowerNode()
    }

    private func placeMowerNode() {
        mowerNode?.removeFromParent()
        let node = GoonRenderer.sprite(
            named: "mower-body",
            size: Self.mowerSize,
            fallbackColor: SKColor(red: 1.0, green: 0.8, blue: 0.0, alpha: 1)
        )
        node.position = mower.position
        node.zPosition = 10
        addChild(node)
        mowerNode = node
    }

    private func clampToLawn(_ p: CGPoint) -> CGPoint {
        let half = Self.mowerSize.width / 2
        return CGPoint(
            x: max(half, min(p.x, size.width - half)),
            y: max(half, min(p.y, size.height - half))
        )
    }

    func drawGrid() {
        gridLayer.removeAllChildren()
        let ts = GoonRenderer.tileSize
        for y in 0..<GoonGrid.height {
            for x in 0..<GoonGrid.width {
                let node = GoonRenderer.tileNode(for: grid.at(x, y))
                // Origin at top-left of lawn; tile centers stride by tileSize
                node.position = CGPoint(
                    x: CGFloat(x) * ts + ts / 2,
                    y: size.height - (CGFloat(y) * ts + ts / 2)
                )
                gridLayer.addChild(node)
            }
        }
    }

    // MARK: - SpriteKit lifecycle
    override func didMove(to view: SKView) {
        super.didMove(to: view)
        if gridLayer.parent == nil {
            addChild(gridLayer)
        }
    }

    func retry() {
        startLevel(levelNum)
    }

    func nextLevel() {
        if levelNum >= GoonLevels.all.count {
            saveWon()
            phase = .win
        } else {
            let next = levelNum + 1
            save(level: next)
            startLevel(next)
        }
    }

    func resetAndReturnToTitle() {
        levelNum = 1
        score = 0
        phase = .title
    }

    func tickGameLogic(deltaSeconds: CGFloat) {
        guard phase == .playing else { return }

        // Apply input to mower
        let dir = input.joystick
        let speed = Self.mowerSpeed * deltaSeconds
        mower.velocity = CGVector(dx: dir.dx * speed, dy: -dir.dy * speed)   // SwiftUI y is inverted vs SpriteKit
        let dx = mower.velocity.dx
        let dy = mower.velocity.dy
        let mag = sqrt(dx * dx + dy * dy)
        if mag > 0.01 {
            mower.facing = atan2(dy, dx)
        }
        let proposed = CGPoint(
            x: mower.position.x + mower.velocity.dx,
            y: mower.position.y + mower.velocity.dy
        )
        mower.position = clampToLawn(proposed)
        mowerNode?.position = mower.position
        mowerNode?.zRotation = mower.facing

        // Game-over check
        if gas <= 0 {
            phase = .gameOver
            return
        }
        let pct = cutPctOverride ?? Double(grid.cutPercentage)
        if pct >= Double(config.win) {
            if levelNum >= GoonLevels.all.count {
                saveWon()
                phase = .win
            } else {
                phase = .levelComplete
            }
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

// MARK: - Persistence

extension GoonGameScene {
    private static let savedLevelKey = "goon_level"
    private static let hasWonKey = "goon_won"

    static var savedLevel: Int {
        let n = UserDefaults.standard.integer(forKey: savedLevelKey)
        return n == 0 ? 1 : min(n, GoonLevels.all.count)
    }

    static var hasWon: Bool {
        UserDefaults.standard.bool(forKey: hasWonKey)
    }

    fileprivate func save(level: Int) {
        UserDefaults.standard.set(level, forKey: Self.savedLevelKey)
    }

    fileprivate func saveWon() {
        UserDefaults.standard.set(true, forKey: Self.hasWonKey)
    }

    fileprivate func clearProgress() {
        UserDefaults.standard.removeObject(forKey: Self.savedLevelKey)
        UserDefaults.standard.removeObject(forKey: Self.hasWonKey)
    }

    func replayFromWin() {
        clearProgress()
        levelNum = 1
        score = 0
        phase = .title
    }
}

#if DEBUG
extension GoonGameScene {
    var phaseForTesting: GoonPhase {
        get { phase }
        set { phase = newValue }
    }
}
#endif
