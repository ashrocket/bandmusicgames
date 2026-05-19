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

struct GoonGasCan {
    let tileX: Int
    let tileY: Int
    let position: CGPoint
    var collected: Bool
    let node: SKNode
}

struct GoonStump {
    let tileX: Int
    let tileY: Int
    let position: CGPoint
    var progress: CGFloat
    var dug: Bool
    let barBackground: SKNode
    let barFill: SKNode
}

struct GoonCricket {
    var tileX: Int
    var tileY: Int
    var position: CGPoint
    var splatted: Bool
    var node: SKNode
}

@MainActor
final class GoonGameScene: SKScene, ObservableObject {

    // MARK: - Constants
    private static let mowerSpeed: CGFloat = 220  // points per second
    private static let mowerSize = CGSize(width: 56, height: 56)
    private static let gasCanSize = CGSize(width: 30, height: 30)
    private static let gasCanPickupDistance = GoonRenderer.tileSize
    private static let stumpDigDistance = GoonRenderer.tileSize * 2
    private static let stumpDigRate: CGFloat = 0.35
    private static let cricketSize = CGSize(width: 24, height: 24)
    private static let cricketCollisionDistance = GoonRenderer.tileSize * 0.75
    private static let obstacleCollisionInset: CGFloat = 12

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
    private(set) var gasCans: [GoonGasCan] = []
    private(set) var stumps: [GoonStump] = []
    private(set) var crickets: [GoonCricket] = []
    private var mowerNode: SKNode?
    private var occupiedPlacementTiles: Set<Int> = []
    private var cricketHopElapsed: CGFloat = 0
    private var cricketHopSequence: Int = 0

    /// Test hook — when non-nil, used in place of grid.cutPercentage by tickGameLogic.
    var cutPctOverride: Double?

    // MARK: - Render layers
    private let gridLayer = SKNode()
    private let itemLayer = SKNode()
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
        gasCans.removeAll(keepingCapacity: true)
        stumps.removeAll(keepingCapacity: true)
        crickets.removeAll(keepingCapacity: true)
        occupiedPlacementTiles.removeAll(keepingCapacity: true)
        cricketHopElapsed = 0
        cricketHopSequence = 0
        itemLayer.removeAllChildren()
        mower.position = CGPoint(x: size.width / 2, y: size.height / 2)
        mower.velocity = .zero
        mower.facing = 0
        phase = .playing
        placeStumpTiles()
        drawGrid()
        placeStumpProgressNodes()
        placeGasCanNodes()
        placeCricketNodes()
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

    private func isBlockedByObstacle(at point: CGPoint) -> Bool {
        let h = Self.obstacleCollisionInset
        let samples = [
            CGPoint(x: point.x - h, y: point.y - h),
            CGPoint(x: point.x + h, y: point.y - h),
            CGPoint(x: point.x - h, y: point.y + h),
            CGPoint(x: point.x + h, y: point.y + h),
        ]

        for sample in samples {
            guard let coordinate = tileCoordinate(atWorldPos: sample) else { return true }
            switch grid.at(coordinate.x, coordinate.y) {
            case .stump, .house:
                return true
            default:
                break
            }
        }

        return false
    }

    private func movedPosition(from current: CGPoint, by velocity: CGVector) -> CGPoint {
        let proposedX = clampToLawn(CGPoint(x: current.x + velocity.dx, y: current.y))
        let afterX = isBlockedByObstacle(at: proposedX) ? current : proposedX
        let proposedY = clampToLawn(CGPoint(x: afterX.x, y: afterX.y + velocity.dy))
        return isBlockedByObstacle(at: proposedY) ? afterX : proposedY
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

    private func worldCenterForTile(x: Int, y: Int) -> CGPoint {
        let ts = GoonRenderer.tileSize
        return CGPoint(
            x: CGFloat(x) * ts + ts / 2,
            y: size.height - (CGFloat(y) * ts + ts / 2)
        )
    }

    private func placementTiles(count: Int, minManhattanFromCenter: Int, salt: Int) -> [(x: Int, y: Int)] {
        guard count > 0 else { return [] }
        let center = (x: GoonGrid.width / 2, y: GoonGrid.height / 2)
        var results: [(x: Int, y: Int)] = []
        func appendIfAvailable(x: Int, y: Int) {
            guard results.count < count else { return }
            guard x > 0, x < GoonGrid.width - 1, y > 0, y < GoonGrid.height - 1 else { return }
            guard grid.at(x, y) == .tall else { return }
            guard abs(x - center.x) + abs(y - center.y) >= minManhattanFromCenter else { return }
            let index = tileIndex(x, y)
            guard !occupiedPlacementTiles.contains(index) else { return }
            occupiedPlacementTiles.insert(index)
            results.append((x, y))
        }

        for attempt in 0..<(GoonGrid.width * GoonGrid.height * 2) {
            let x = 1 + ((attempt * 7 + salt * 11) % (GoonGrid.width - 2))
            let y = 1 + ((attempt * 13 + salt * 5) % (GoonGrid.height - 2))
            appendIfAvailable(x: x, y: y)
        }

        if results.count < count {
            for y in 1..<(GoonGrid.height - 1) {
                for x in 1..<(GoonGrid.width - 1) {
                    appendIfAvailable(x: x, y: y)
                }
            }
        }

        return results
    }

    private func placeGasCanNodes() {
        for tile in placementTiles(count: config.cans, minManhattanFromCenter: 6, salt: levelNum * 17 + 3) {
            let position = worldCenterForTile(x: tile.x, y: tile.y)
            let node = GoonRenderer.gasCanNode(size: Self.gasCanSize)
            node.position = position
            node.zPosition = 7
            let bob = SKAction.sequence([
                SKAction.moveBy(x: 0, y: 5, duration: 0.58),
                SKAction.moveBy(x: 0, y: -5, duration: 0.58),
            ])
            bob.timingMode = .easeInEaseOut
            node.run(SKAction.repeatForever(bob), withKey: "gas-can-bob")
            itemLayer.addChild(node)
            gasCans.append(
                GoonGasCan(
                    tileX: tile.x,
                    tileY: tile.y,
                    position: position,
                    collected: false,
                    node: node
                )
            )
        }
    }

    private func placeStumpTiles() {
        for tile in placementTiles(count: config.stumps, minManhattanFromCenter: 5, salt: levelNum * 23 + 9) {
            grid.set(tile.x, tile.y, .stump)
            stumps.append(
                GoonStump(
                    tileX: tile.x,
                    tileY: tile.y,
                    position: worldCenterForTile(x: tile.x, y: tile.y),
                    progress: 0,
                    dug: false,
                    barBackground: SKNode(),
                    barFill: SKNode()
                )
            )
        }
    }

    private func placeStumpProgressNodes() {
        for index in stumps.indices {
            let stump = stumps[index]
            let nodes = GoonRenderer.stumpProgressNodes()
            let position = CGPoint(x: stump.position.x, y: stump.position.y + 26)
            nodes.background.position = position
            nodes.fill.position = position
            nodes.background.zPosition = 14
            nodes.fill.zPosition = 15
            nodes.background.isHidden = true
            nodes.fill.isHidden = true
            nodes.fill.xScale = 0.001
            itemLayer.addChild(nodes.background)
            itemLayer.addChild(nodes.fill)
            stumps[index] = GoonStump(
                tileX: stump.tileX,
                tileY: stump.tileY,
                position: stump.position,
                progress: stump.progress,
                dug: stump.dug,
                barBackground: nodes.background,
                barFill: nodes.fill
            )
        }
    }

    private func placeCricketNodes() {
        for tile in placementTiles(count: config.crickets, minManhattanFromCenter: 3, salt: levelNum * 31 + 11) {
            let position = worldCenterForTile(x: tile.x, y: tile.y)
            let node = GoonRenderer.cricketNode(size: Self.cricketSize)
            node.position = position
            node.zPosition = 8
            itemLayer.addChild(node)
            crickets.append(
                GoonCricket(
                    tileX: tile.x,
                    tileY: tile.y,
                    position: position,
                    splatted: false,
                    node: node
                )
            )
        }
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
        if itemLayer.parent == nil {
            addChild(itemLayer)
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
        let inputMagnitude = sqrt(dir.dx * dir.dx + dir.dy * dir.dy)
        let isMoving = inputMagnitude > 0.01
        let speed = Self.mowerSpeed * deltaSeconds
        mower.velocity = CGVector(dx: dir.dx * speed, dy: -dir.dy * speed)   // SwiftUI y inverted vs SpriteKit
        let mag = sqrt(mower.velocity.dx * mower.velocity.dx + mower.velocity.dy * mower.velocity.dy)
        if mag > 0.01 {
            mower.facing = atan2(mower.velocity.dy, mower.velocity.dx)
        }
        mower.position = movedPosition(from: mower.position, by: mower.velocity)
        mowerNode?.position = mower.position
        mowerNode?.zRotation = mower.facing

        // Cut tiles under the mower
        if isMoving {
            let cutCoordinate = tileCoordinate(atWorldPos: mower.position)
            let cuts = grid.cutTilesUnderMower(atWorldPos: mower.position, sceneHeight: size.height)
            if cuts > 0 {
                score += 1
                if let cutCoordinate {
                    redrawTile(x: cutCoordinate.x, y: cutCoordinate.y, animated: true)
                }
            }
        }

        // Gas drain (~16.67ms per frame in web; deltaSeconds * 60 is the scale factor)
        if isMoving {
            let drainScale: CGFloat = deltaSeconds * 60
            let mowerX = Int(mower.position.x / GoonRenderer.tileSize)
            let mowerY = Int((size.height - mower.position.y) / GoonRenderer.tileSize)
            let onCut = grid.at(mowerX, mowerY) == .cut
            let drain = onCut ? config.gasDrain * 0.4 : config.gasDrain
            gas = max(0, gas - drain * drainScale)
        }

        checkGasCans()
        checkStumps(deltaSeconds: deltaSeconds)
        checkCrickets()
        moveCrickets(deltaSeconds: deltaSeconds)

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

    private func checkGasCans() {
        guard !gasCans.isEmpty else { return }

        for index in gasCans.indices where !gasCans[index].collected {
            let dx = mower.position.x - gasCans[index].position.x
            let dy = mower.position.y - gasCans[index].position.y
            let distance = sqrt(dx * dx + dy * dy)
            if distance < Self.gasCanPickupDistance {
                collectGasCan(at: index)
            }
        }
    }

    private func collectGasCan(at index: Int) {
        gasCans[index].collected = true
        gas = config.gasMax

        let node = gasCans[index].node
        node.removeAllActions()
        let pop = SKAction.group([
            SKAction.scale(to: 1.35, duration: 0.10),
            SKAction.fadeAlpha(to: 0, duration: 0.16),
        ])
        pop.timingMode = .easeOut
        node.run(SKAction.sequence([pop, .removeFromParent()]))

        let emitter = GoonRenderer.gasPickupEmitter()
        emitter.position = gasCans[index].position
        itemLayer.addChild(emitter)
        emitter.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.45),
            SKAction.removeFromParent(),
        ]))
    }

    private func checkStumps(deltaSeconds: CGFloat) {
        guard !stumps.isEmpty else { return }

        for index in stumps.indices where !stumps[index].dug {
            let dx = mower.position.x - stumps[index].position.x
            let dy = mower.position.y - stumps[index].position.y
            let near = sqrt(dx * dx + dy * dy) < Self.stumpDigDistance
            stumps[index].barBackground.isHidden = !near
            stumps[index].barFill.isHidden = !near

            if near && input.digging {
                stumps[index].progress = min(1, stumps[index].progress + Self.stumpDigRate * deltaSeconds)
                stumps[index].barFill.xScale = max(0.001, stumps[index].progress)
                if stumps[index].progress >= 1 {
                    removeStump(at: index)
                }
            }
        }
    }

    private func removeStump(at index: Int) {
        stumps[index].dug = true
        stumps[index].barBackground.removeFromParent()
        stumps[index].barFill.removeFromParent()
        grid.set(stumps[index].tileX, stumps[index].tileY, .cut)
        redrawTile(x: stumps[index].tileX, y: stumps[index].tileY, animated: true)
    }

    private func checkCrickets() {
        guard !crickets.isEmpty else { return }

        for index in crickets.indices where !crickets[index].splatted {
            let dx = mower.position.x - crickets[index].position.x
            let dy = mower.position.y - crickets[index].position.y
            let distance = sqrt(dx * dx + dy * dy)
            if distance < Self.cricketCollisionDistance {
                splatCricket(at: index)
            }
        }
    }

    private func splatCricket(at index: Int) {
        crickets[index].splatted = true
        gas = max(0, gas - 30)

        let oldNode = crickets[index].node
        let splat = GoonRenderer.cricketSplatNode(size: Self.cricketSize)
        splat.position = crickets[index].position
        splat.zPosition = oldNode.zPosition
        oldNode.removeAllActions()
        oldNode.removeFromParent()
        itemLayer.addChild(splat)
        crickets[index].node = splat
    }

    private func moveCrickets(deltaSeconds: CGFloat) {
        guard config.crickets > 0, config.cricketMs > 0 else { return }

        cricketHopElapsed += deltaSeconds
        let hopInterval = CGFloat(config.cricketMs) / 1000
        guard cricketHopElapsed >= hopInterval else { return }

        cricketHopElapsed = cricketHopElapsed.truncatingRemainder(dividingBy: hopInterval)
        cricketHopSequence += 1

        for index in crickets.indices where !crickets[index].splatted {
            hopCricket(at: index)
        }
    }

    private func hopCricket(at index: Int) {
        for direction in cricketDirections(for: index) {
            let nx = crickets[index].tileX + direction.x
            let ny = crickets[index].tileY + direction.y
            guard nx >= 0, nx < GoonGrid.width, ny >= 0, ny < GoonGrid.height else { continue }
            switch grid.at(nx, ny) {
            case .stump, .house:
                continue
            default:
                crickets[index].tileX = nx
                crickets[index].tileY = ny
                crickets[index].position = worldCenterForTile(x: nx, y: ny)
                crickets[index].node.position = crickets[index].position
                let hop = SKAction.sequence([
                    SKAction.scaleX(to: 1.18, y: 0.82, duration: 0.08),
                    SKAction.scaleX(to: 0.92, y: 1.22, duration: 0.08),
                    SKAction.scale(to: 1, duration: 0.10),
                ])
                crickets[index].node.run(hop, withKey: "cricket-hop")
                return
            }
        }
    }

    private func cricketDirections(for index: Int) -> [(x: Int, y: Int)] {
        let directions: [(x: Int, y: Int)] = [(x: -1, y: 0), (x: 1, y: 0), (x: 0, y: -1), (x: 0, y: 1)]
        let start = abs((levelNum * 31 + index * 17 + cricketHopSequence * 7) % directions.count)
        return (0..<directions.count).map { directions[(start + $0) % directions.count] }
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
