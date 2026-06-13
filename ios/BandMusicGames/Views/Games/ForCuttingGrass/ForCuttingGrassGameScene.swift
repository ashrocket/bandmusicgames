import SpriteKit
import Combine

enum ForCuttingGrassPhase {
    case title
    case playing
    case levelComplete
    case gameOver
    case win
}

struct ForCuttingGrassMower {
    var position: CGPoint
    var velocity: CGVector
    var facing: CGFloat    // radians
}

enum ForCuttingGrassPlayfieldLayout {
    static func swiftUIFrame(in size: CGSize) -> CGRect {
        let topReserved: CGFloat = 8
        let bottomInset: CGFloat = 8
        let availableHeight = max(200, size.height - topReserved - bottomInset)
        let aspect = CGFloat(ForCuttingGrassGrid.width) / CGFloat(ForCuttingGrassGrid.height)
        var width = size.width
        var height = width / aspect
        if height > availableHeight {
            height = availableHeight
            width = height * aspect
        }
        return CGRect(
            x: (size.width - width) / 2,
            y: topReserved,
            width: width,
            height: min(height, size.height - topReserved)
        )
    }

    static func spriteKitFrame(in size: CGSize) -> CGRect {
        let frame = swiftUIFrame(in: size)
        return CGRect(
            x: frame.minX,
            y: size.height - frame.maxY,
            width: frame.width,
            height: frame.height
        )
    }
}

@MainActor
final class ForCuttingGrassGameScene: SKScene, ObservableObject {

    // MARK: - Constants
    private static let mowerSpeed: CGFloat = 220
    private static let maxTries = 3
    private static let savedLevelKey = "for_cutting_grass_level"
    private static let hasWonKey = "for_cutting_grass_won"

    // MARK: - Phase state
    @Published private(set) var phase: ForCuttingGrassPhase = .title

    // MARK: - Level state
    private(set) var levelNum: Int = 1
    var config: ForCuttingGrassLevelConfig { ForCuttingGrassLevels.all[levelNum - 1] }
    @Published private(set) var triesRemaining = ForCuttingGrassGameScene.maxTries
    @Published private(set) var gameOverTitle = "NO TRIES LEFT"

    // MARK: - Runtime state
    @Published private(set) var gas: CGFloat = 0
    private var gasLowWarned = false
    private var wallHapticCooldownUntil: TimeInterval = 0
    var grid = ForCuttingGrassGrid(cells: ContiguousArray<ForCuttingGrassTile>(repeating: .tall, count: ForCuttingGrassGrid.width * ForCuttingGrassGrid.height))
    var score: Int = 0
    var mower: ForCuttingGrassMower = ForCuttingGrassMower(position: .zero, velocity: .zero, facing: 0)
    var gasCans: [ForCuttingGrassGasCan] = []
    var stumps: [ForCuttingGrassStump] = []
    var crickets: [ForCuttingGrassCricket] = []
    var skunks: [ForCuttingGrassSkunk] = []

    var input = ForCuttingGrassInputController()

    // MARK: - Nodes
    private let gridLayer = SKNode()
    private let entitiesLayer = SKNode()
    private var mowerNode: SKNode?
    private var lastUpdate: TimeInterval?

    private struct GridMetrics {
        let frame: CGRect
        let tileSize: CGSize
    }

    private var gridMetrics: GridMetrics {
        let frame = ForCuttingGrassPlayfieldLayout.spriteKitFrame(in: size)
        return GridMetrics(
            frame: frame,
            tileSize: CGSize(
                width: frame.width / CGFloat(ForCuttingGrassGrid.width),
                height: frame.height / CGFloat(ForCuttingGrassGrid.height)
            )
        )
    }

    private var objectUnit: CGFloat {
        let metrics = gridMetrics
        return max(18, min(34, metrics.tileSize.width * 1.55))
    }

    private var mowerSize: CGSize {
        let side = max(30, min(54, gridMetrics.tileSize.width * 2.1))
        return CGSize(width: side, height: side)
    }

    // MARK: - Construction
    static func make() -> ForCuttingGrassGameScene {
        let scene = ForCuttingGrassGameScene(size: CGSize(width: 393, height: 852))
        scene.scaleMode = .resizeFill
        scene.backgroundColor = SKColor(red: 0.04, green: 0.10, blue: 0.04, alpha: 1)
        return scene
    }

    // MARK: - Lifecycle
    override func didMove(to view: SKView) {
        super.didMove(to: view)
        if gridLayer.parent == nil { addChild(gridLayer) }
        if entitiesLayer.parent == nil { addChild(entitiesLayer) }
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard phase == .playing, oldSize != .zero, oldSize != size else { return }
        startLevel(levelNum)
    }

    func activate() {
        startLevel(Self.savedLevel)
    }

    func deactivate() {
        lastUpdate = nil
    }

    // MARK: - Transitions
    func startLevel(_ n: Int, resetTries: Bool = true) {
        levelNum = max(1, min(n, ForCuttingGrassLevels.all.count))
        if resetTries {
            triesRemaining = Self.maxTries
        }
        gameOverTitle = "NO TRIES LEFT"
        grid = ForCuttingGrassGrid.make(for: config)
        gas = config.gasMax
        gasLowWarned = false
        wallHapticCooldownUntil = 0
        score = 0

        mower.position = startPosition(for: config)
        mower.velocity = .zero
        mower.facing = 0

        input.canDig = config.stumps > 0
        input.reset()

        placeGasCans()
        placeStumps()
        placeCrickets()
        placeSkunks()

        phase = .playing
        drawGrid()
        placeMowerNode()
    }

    func retry() {
        startLevel(levelNum)
    }

    func nextLevel() {
        if levelNum >= ForCuttingGrassLevels.all.count {
            saveWon()
            phase = .win
        } else {
            let next = levelNum + 1
            save(level: next)
            startLevel(next)
        }
    }

    func replayFromWin() {
        clearProgress()
        startLevel(1)
    }

    // MARK: - Entity Placement
    private func placeGasCans() {
        gasCans.removeAll()
        for _ in 0..<config.cans {
            gasCans.append(ForCuttingGrassGasCan(position: randomLawnPosition()))
        }
    }

    private func placeStumps() {
        stumps.removeAll()
        for _ in 0..<config.stumps {
            let pos = randomLawnPosition()
            stumps.append(ForCuttingGrassStump(position: pos))
            if let tile = tileCoordinate(atWorldPos: pos) {
                grid.set(tile.x, tile.y, .stump)
            }
        }
    }

    private func placeCrickets() {
        crickets.removeAll()
        let now = lastUpdate ?? 0
        for _ in 0..<config.crickets {
            crickets.append(ForCuttingGrassCricket(position: randomLawnPosition(), velocity: .zero, nextHopAt: now + Double.random(in: 0...1.0)))
        }
    }

    private func placeSkunks() {
        skunks.removeAll()
        let now = lastUpdate ?? 0
        for _ in 0..<config.skunks {
            skunks.append(ForCuttingGrassSkunk(position: randomLawnPosition(), velocity: .zero, alarm: 0, changeDirAt: now + 0.5))
        }
    }

    private func randomLawnPosition() -> CGPoint {
        var attempts = 0
        while attempts < 50 {
            let x = Int.random(in: 0..<ForCuttingGrassGrid.width)
            let y = Int.random(in: 0..<ForCuttingGrassGrid.height)
            if grid.at(x, y) == .tall || grid.at(x, y) == .cut {
                return worldPositionForTile(x: x, y: y)
            }
            attempts += 1
        }
        return worldPositionForTile(x: ForCuttingGrassGrid.width / 2, y: ForCuttingGrassGrid.height / 2)
    }

    // MARK: - Rendering
    func drawGrid() {
        gridLayer.removeAllChildren()
        let metrics = gridMetrics
        for y in 0..<ForCuttingGrassGrid.height {
            for x in 0..<ForCuttingGrassGrid.width {
                let node = ForCuttingGrassRenderer.tileNode(for: grid.at(x, y), size: metrics.tileSize)
                node.position = worldPositionForTile(x: x, y: y)
                gridLayer.addChild(node)
            }
        }
    }

    private func placeMowerNode() {
        mowerNode?.removeFromParent()
        let node = ForCuttingGrassRenderer.pushMowerNode(size: mowerSize)
        node.position = mower.position
        node.zPosition = 10
        addChild(node)
        mowerNode = node
    }

    private func redrawTile(atWorldPos pos: CGPoint) {
        guard let tile = tileCoordinate(atWorldPos: pos) else { return }
        let center = worldPositionForTile(x: tile.x, y: tile.y)
        for child in gridLayer.children where abs(child.position.x - center.x) < 0.5 && abs(child.position.y - center.y) < 0.5 {
            child.removeFromParent()
            break
        }
        let node = ForCuttingGrassRenderer.tileNode(for: grid.at(tile.x, tile.y), size: gridMetrics.tileSize)
        node.position = center
        gridLayer.addChild(node)
    }

    private func syncEntityNodes() {
        entitiesLayer.removeAllChildren()
        let unit = objectUnit
        for can in gasCans where !can.collected {
            let node = ForCuttingGrassRenderer.sprite(named: "gas-can", size: CGSize(width: unit, height: unit), fallbackColor: .red)
            node.position = can.position; node.zPosition = 5
            entitiesLayer.addChild(node)
        }
        for s in stumps where !s.dug {
            let node = ForCuttingGrassRenderer.sprite(named: s.progress > 0.5 ? "stump-half" : "stump-full", size: CGSize(width: unit * 1.1, height: unit * 1.1), fallbackColor: .brown)
            node.position = s.position; node.zPosition = 6
            entitiesLayer.addChild(node)
        }
        for c in crickets {
            let node = ForCuttingGrassRenderer.sprite(named: "cricket-idle", size: CGSize(width: unit * 0.62, height: unit * 0.62), fallbackColor: .green)
            node.position = c.position; node.zPosition = 7
            entitiesLayer.addChild(node)
        }
        for s in skunks {
            let node = ForCuttingGrassRenderer.sprite(named: "skunk-walk-1", size: CGSize(width: unit * 0.88, height: unit * 0.88), fallbackColor: .black)
            node.position = s.position; node.zPosition = 7
            entitiesLayer.addChild(node)
        }
    }

    // MARK: - Update Loop
    override func update(_ currentTime: TimeInterval) {
        let dt = lastUpdate.map { CGFloat(currentTime - $0) } ?? 0.016
        lastUpdate = currentTime
        tickGameLogic(deltaSeconds: dt)
    }

    func tickGameLogic(deltaSeconds: CGFloat) {
        guard phase == .playing else { return }

        // Mower movement
        let rawDirection = input.joystick
        let directionMagnitude = vectorMagnitude(rawDirection)
        let throttle = max(0, min(1, input.throttle))
        let dir = directionMagnitude > 0.001
            ? CGVector(dx: rawDirection.dx / directionMagnitude, dy: rawDirection.dy / directionMagnitude)
            : .zero
        let isDriving = throttle > 0.01 && directionMagnitude > 0.01
        let speed = Self.mowerSpeed * deltaSeconds * throttle
        mower.velocity = CGVector(dx: dir.dx * speed, dy: -dir.dy * speed)
        if isDriving {
            mower.facing = atan2(mower.velocity.dy, mower.velocity.dx)
            moveMower(by: mower.velocity)
        }
        mowerNode?.position = mower.position
        mowerNode?.zRotation = mower.facing

        if throttle > 0.01 && isCuttingFlowers(at: mower.position) {
            restartAfterCuttingFlowers()
            return
        }

        let tileBeforeCut = tile(atWorldPos: mower.position)

        // Cutting
        if isDriving {
            let cuts = cutTile(atWorldPos: mower.position)
            if cuts > 0 {
                score += 1
                redrawTile(atWorldPos: mower.position)
            }
        }

        if config.usesGas {
            if isDriving {
                let drainScale = deltaSeconds * 60
                let drain = tileBeforeCut == .cut ? config.gasDrain * 0.4 : config.gasDrain
                gas = max(0, gas - drain * drainScale * throttle)
            }

            if !gasLowWarned, config.gasMax > 0, gas / config.gasMax < 0.2 {
                gasLowWarned = true
                HapticManager.impact(.heavy)
            }
            if gas <= 0 {
                gameOverTitle = "GAS OUT"
                HapticManager.notification(.error)
                phase = .gameOver
                return
            }
        } else {
            gas = config.gasMax
        }

        // Pickups & Hazards
        let now = lastUpdate ?? 0
        checkPickupsAndHazards(now: now, delta: deltaSeconds)

        // Win condition
        if grid.cutPercentage >= config.win {
            HapticManager.notification(.success)
            if levelNum >= ForCuttingGrassLevels.all.count { saveWon(); phase = .win }
            else { phase = .levelComplete }
        }

        syncEntityNodes()
    }

    private func checkPickupsAndHazards(now: TimeInterval, delta: CGFloat) {
        let unit = objectUnit

        // Gas cans
        for i in gasCans.indices where !gasCans[i].collected {
            let pickupRadius = unit * 1.45
            if distanceSq(gasCans[i].position, mower.position) < pickupRadius * pickupRadius {
                gasCans[i].collected = true
                gas = config.gasMax
                gasLowWarned = false
                HapticManager.impact(.medium)
            }
        }

        // Stumps
        if input.digging {
            for i in stumps.indices where !stumps[i].dug {
                let digRadius = unit * 1.6
                if distanceSq(stumps[i].position, mower.position) < digRadius * digRadius {
                    let prevProgress = stumps[i].progress
                    stumps[i].progress += delta * 0.6
                    if prevProgress < 0.5 && stumps[i].progress >= 0.5 {
                        HapticManager.impact(.light)
                    }
                    if stumps[i].progress >= 1.0 {
                        stumps[i].dug = true
                        if let tile = tileCoordinate(atWorldPos: stumps[i].position) {
                            grid.set(tile.x, tile.y, .cut)
                        }
                        redrawTile(atWorldPos: stumps[i].position)
                        HapticManager.notification(.success)
                    }
                }
            }
        }
        // Crickets
        let bounds = gridMetrics.frame.insetBy(dx: gridMetrics.tileSize.width / 2, dy: gridMetrics.tileSize.height / 2)
        ForCuttingGrassHazards.tickCrickets(&crickets, delta: delta, now: now, bounds: bounds, cricketMs: config.cricketMs)
        for i in crickets.indices where now >= crickets[i].hitCooldownUntil {
            let hitRadius = unit * 1.25
            if distanceSq(crickets[i].position, mower.position) < hitRadius * hitRadius {
                crickets[i].hitCooldownUntil = now + 1.0
                let dx = crickets[i].position.x - mower.position.x, dy = crickets[i].position.y - mower.position.y
                let dist = sqrt(dx*dx + dy*dy)
                if dist > 0.01 { crickets[i].velocity = CGVector(dx: (dx/dist)*200, dy: (dy/dist)*200) }
                HapticManager.impact(.light)
            }
        }
        // Skunks
        ForCuttingGrassHazards.tickSkunks(&skunks, delta: delta, now: now, bounds: bounds, mowerPos: mower.position)
        for i in skunks.indices where now >= skunks[i].hitCooldownUntil {
            let hitRadius = unit * 1.5
            if distanceSq(skunks[i].position, mower.position) < hitRadius * hitRadius {
                skunks[i].hitCooldownUntil = now + 3.0
                triesRemaining -= 1
                HapticManager.notification(.error)
                flashRed()
                if triesRemaining <= 0 {
                    gameOverTitle = "SKUNKED OUT!"
                    phase = .gameOver
                } else {
                    startLevel(levelNum, resetTries: false)
                }
                return
            }
        }
    }

    private func restartAfterCuttingFlowers() {
        triesRemaining -= 1
        HapticManager.notification(.error)
        flashRed()

        guard triesRemaining > 0 else {
            gameOverTitle = "NO TRIES LEFT"
            phase = .gameOver
            return
        }

        startLevel(levelNum, resetTries: false)
    }

    private func flashRed() {
        let flash = SKShapeNode(rect: CGRect(origin: .zero, size: size))
        flash.fillColor = SKColor(red: 1, green: 0.1, blue: 0.1, alpha: 0.55)
        flash.strokeColor = .clear
        flash.zPosition = 900
        addChild(flash)
        flash.run(SKAction.sequence([
            SKAction.fadeOut(withDuration: 0.35),
            SKAction.removeFromParent()
        ]))
    }

    private func clampToLawn(_ p: CGPoint) -> CGPoint {
        let frame = gridMetrics.frame
        let half = mowerSize.width / 2
        return CGPoint(
            x: max(frame.minX + half, min(p.x, frame.maxX - half)),
            y: max(frame.minY + half, min(p.y, frame.maxY - half))
        )
    }

    private func moveMower(by displacement: CGVector) {
        var hitWall = false

        let nextX = clampToLawn(CGPoint(x: mower.position.x + displacement.dx, y: mower.position.y))
        if !isBlocked(nextX) {
            mower.position.x = nextX.x
        } else { hitWall = true }

        let nextY = clampToLawn(CGPoint(x: mower.position.x, y: mower.position.y + displacement.dy))
        if !isBlocked(nextY) {
            mower.position.y = nextY.y
        } else { hitWall = true }

        let now = lastUpdate ?? 0
        if hitWall, now > wallHapticCooldownUntil {
            wallHapticCooldownUntil = now + 0.45
            HapticManager.impact(.rigid)
        }
    }

    private func isBlocked(_ position: CGPoint) -> Bool {
        let half = max(9, mowerSize.width * 0.36)
        let probes = [
            CGPoint(x: position.x - half, y: position.y - half),
            CGPoint(x: position.x + half, y: position.y - half),
            CGPoint(x: position.x - half, y: position.y + half),
            CGPoint(x: position.x + half, y: position.y + half),
        ]

        return probes.contains { probe in
            let tile = tile(atWorldPos: probe)
            return tile == .house || tile == .stump || tile == .birdbath
        }
    }

    private func isCuttingFlowers(at position: CGPoint) -> Bool {
        let half = max(8, mowerSize.width * 0.32)
        let probes = [
            position,
            CGPoint(x: position.x - half, y: position.y - half),
            CGPoint(x: position.x + half, y: position.y - half),
            CGPoint(x: position.x - half, y: position.y + half),
            CGPoint(x: position.x + half, y: position.y + half),
        ]

        return probes.contains { tile(atWorldPos: $0) == .garden }
    }

    private func tile(atWorldPos pos: CGPoint) -> ForCuttingGrassTile {
        guard let tile = tileCoordinate(atWorldPos: pos) else { return .house }
        return grid.at(tile.x, tile.y)
    }

    private func startPosition(for config: ForCuttingGrassLevelConfig) -> CGPoint {
        if config.n == 1 {
            return worldPositionForTile(x: ForCuttingGrassGrid.width / 2, y: ForCuttingGrassGrid.height - 8)
        }

        return worldPositionForTile(x: ForCuttingGrassGrid.width / 2, y: ForCuttingGrassGrid.height / 2)
    }

    private func worldPositionForTile(x: Int, y: Int) -> CGPoint {
        let metrics = gridMetrics
        return CGPoint(
            x: metrics.frame.minX + CGFloat(x) * metrics.tileSize.width + metrics.tileSize.width / 2,
            y: metrics.frame.maxY - (CGFloat(y) * metrics.tileSize.height + metrics.tileSize.height / 2)
        )
    }

    private func tileCoordinate(atWorldPos pos: CGPoint) -> (x: Int, y: Int)? {
        let metrics = gridMetrics
        guard metrics.frame.contains(pos) else { return nil }
        let x = Int(floor((pos.x - metrics.frame.minX) / metrics.tileSize.width))
        let y = Int(floor((metrics.frame.maxY - pos.y) / metrics.tileSize.height))
        guard x >= 0, x < ForCuttingGrassGrid.width, y >= 0, y < ForCuttingGrassGrid.height else { return nil }
        return (x, y)
    }

    private func cutTile(atWorldPos pos: CGPoint) -> Int {
        guard let tile = tileCoordinate(atWorldPos: pos), grid.at(tile.x, tile.y) == .tall else {
            return 0
        }
        grid.set(tile.x, tile.y, .cut)
        return 1
    }

    private func distanceSq(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = a.x - b.x, dy = a.y - b.y
        return dx * dx + dy * dy
    }

    private func vectorMagnitude(_ vector: CGVector) -> CGFloat {
        sqrt(vector.dx * vector.dx + vector.dy * vector.dy)
    }

    // MARK: - Persistence
    static var savedLevel: Int {
        let n = UserDefaults.standard.integer(forKey: savedLevelKey)
        return n == 0 ? 1 : min(n, ForCuttingGrassLevels.all.count)
    }
    static var hasWon: Bool { UserDefaults.standard.bool(forKey: hasWonKey) }
    private func save(level: Int) { UserDefaults.standard.set(level, forKey: Self.savedLevelKey) }
    private func saveWon() { UserDefaults.standard.set(true, forKey: Self.hasWonKey) }
    private func clearProgress() {
        UserDefaults.standard.removeObject(forKey: Self.savedLevelKey)
        UserDefaults.standard.removeObject(forKey: Self.hasWonKey)
    }
}
