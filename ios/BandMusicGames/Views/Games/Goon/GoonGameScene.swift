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
    private var tileNodes: [Int: SKNode] = [:]

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
        tileNodes.removeAll(keepingCapacity: true)
        let ts = GoonRenderer.tileSize
        for y in 0..<GoonGrid.height {
            for x in 0..<GoonGrid.width {
                let node = GoonRenderer.tileNode(for: grid.at(x, y), x: x, y: y)
                // Origin at top-left of lawn; tile centers stride by tileSize
                node.position = CGPoint(
                    x: CGFloat(x) * ts + ts / 2,
                    y: size.height - (CGFloat(y) * ts + ts / 2)
                )
                gridLayer.addChild(node)
                tileNodes[tileIndex(x, y)] = node
            }
        }
    }

    private func redrawTile(x: Int, y: Int, animated: Bool) {
        let ts = GoonRenderer.tileSize
        guard x >= 0, x < GoonGrid.width, y >= 0, y < GoonGrid.height else { return }
        let cx = CGFloat(x) * ts + ts / 2
        let cy = size.height - (CGFloat(y) * ts + ts / 2)
        let index = tileIndex(x, y)
        tileNodes[index]?.removeFromParent()
        let node = GoonRenderer.tileNode(for: grid.at(x, y), x: x, y: y)
        node.position = CGPoint(x: cx, y: cy)
        gridLayer.addChild(node)
        tileNodes[index] = node
        if animated {
            GoonRenderer.runCutSettleAnimation(on: node)
            emitGrassClippings(at: node.position)
        }
    }

    private func tileIndex(_ x: Int, _ y: Int) -> Int {
        y * GoonGrid.width + x
    }

    private func tileCoordinate(atWorldPos pos: CGPoint) -> (x: Int, y: Int)? {
        let ts = GoonRenderer.tileSize
        let x = Int(pos.x / ts)
        let y = Int((size.height - pos.y) / ts)
        guard x >= 0, x < GoonGrid.width, y >= 0, y < GoonGrid.height else { return nil }
        return (x, y)
    }

    private func emitGrassClippings(at position: CGPoint) {
        let emitter = GoonRenderer.clippingEmitter()
        emitter.position = position
        gridLayer.addChild(emitter)
        let cleanup = SKAction.sequence([
            SKAction.wait(forDuration: 0.55),
            SKAction.removeFromParent(),
        ])
        emitter.run(cleanup)
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

        // Apply input to mower (single joystick: direction = mower velocity vector)
        let dir = input.joystick
        let speed = Self.mowerSpeed * deltaSeconds
        mower.velocity = CGVector(dx: dir.dx * speed, dy: -dir.dy * speed)   // SwiftUI y inverted vs SpriteKit
        let mag = sqrt(mower.velocity.dx * mower.velocity.dx + mower.velocity.dy * mower.velocity.dy)
        if mag > 0.01 {
            mower.facing = atan2(mower.velocity.dy, mower.velocity.dx)
        }
        let proposed = CGPoint(
            x: mower.position.x + mower.velocity.dx,
            y: mower.position.y + mower.velocity.dy
        )
        mower.position = clampToLawn(proposed)
        mowerNode?.position = mower.position
        mowerNode?.zRotation = mower.facing

        // Cut tiles under the mower
        let cutCoordinate = tileCoordinate(atWorldPos: mower.position)
        let cuts = grid.cutTilesUnderMower(atWorldPos: mower.position, sceneHeight: size.height)
        if cuts > 0 {
            score += 1
            if let cutCoordinate {
                redrawTile(x: cutCoordinate.x, y: cutCoordinate.y, animated: true)
            }
        }

        // Gas drain (~16.67ms per frame in web; deltaSeconds * 60 is the scale factor)
        let drainScale: CGFloat = deltaSeconds * 60
        let mowerX = Int(mower.position.x / GoonRenderer.tileSize)
        let mowerY = Int((size.height - mower.position.y) / GoonRenderer.tileSize)
        let onCut = grid.at(mowerX, mowerY) == .cut
        let drain = onCut ? config.gasDrain * 0.4 : config.gasDrain
        gas = max(0, gas - drain * drainScale)

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

        // Notify SwiftUI overlays so gas/score-dependent views redraw.
        objectWillChange.send()
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
