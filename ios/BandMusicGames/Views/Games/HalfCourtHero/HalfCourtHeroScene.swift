import SpriteKit
import Combine
import CoreMotion

@MainActor
final class HalfCourtHeroScene: SKScene, ObservableObject, SKPhysicsContactDelegate {
    
    // MARK: - Constants
    private let hchRimX: CGFloat = 650
    private let hchRimY: CGFloat = 800
    private let hchRimR: CGFloat = 35
    private let seriesWinTarget = 3
    
    // MARK: - Nodes
    private let worldNode = SKNode()
    private let courtLayer = SKNode()
    private let playersLayer = SKNode()
    private let ballLayer = SKNode()
    private let uiLayer = SKNode()
    
    private var ball: BallNode?
    private var players: [HalfCourtHeroID: PlayerNode] = [:]
    private var hud: HalfCourtHUDNode?
    private var resultCard: HalfCourtResultCardNode?
    private var shootButton: ShootButtonNode?

    var onDismiss: (() -> Void)?
    
    // MARK: - State
    @Published private(set) var phase: HalfCourtPhase = .title
    @Published var homeScore = 0
    @Published var awayScore = 0
    @Published var homeSeriesWins = 0
    @Published var awaySeriesWins = 0
    
    private var homeIDs: [HalfCourtHeroID] = []
    private var awayIDs: [HalfCourtHeroID] = []
    private var activeHumanID: HalfCourtHeroID?
    private var possession: HalfCourtTeam = .home
    private var shotClockFrames = 600
    private var lastUpdate: TimeInterval?
    
    private let motion = CMMotionManager()
    
    // MARK: - Construction
    static func make() -> HalfCourtHeroScene {
        let scene = HalfCourtHeroScene(size: CGSize(width: 750, height: 1334))
        scene.scaleMode = .aspectFill
        scene.backgroundColor = SKColor(red: 0.1, green: 0.04, blue: 0.24, alpha: 1) // 1a0a3e
        return scene
    }
    
    override func didMove(to view: SKView) {
        super.didMove(to: view)
        if worldNode.parent == nil {
            addChild(worldNode)
            worldNode.addChild(courtLayer)
            worldNode.addChild(playersLayer)
            worldNode.addChild(ballLayer)
            addChild(uiLayer)
        }
        
        if hud == nil {
            let hudNode = HalfCourtHUDNode(size: size)
            hudNode.zPosition = 100
            uiLayer.addChild(hudNode)
            hud = hudNode
        }

        if shootButton == nil {
            let btn = ShootButtonNode()
            btn.position = CGPoint(x: size.width - 80, y: 120)
            btn.zPosition = 110
            btn.isHidden = true
            uiLayer.addChild(btn)
            shootButton = btn
        }

        setupCourt()
        setupPhysics()
        setupMotion()
    }
    
    private func setupCourt() {
        courtLayer.removeAllChildren()

        // Floor
        let floorY: CGFloat = 40
        let floor = SKShapeNode(rectOf: CGSize(width: size.width, height: floorY))
        floor.fillColor = SKColor(red: 0.16, green: 0.32, blue: 0.58, alpha: 1.0)
        floor.strokeColor = .clear
        floor.position = CGPoint(x: size.width / 2, y: floorY / 2)
        floor.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: size.width, height: floorY))
        floor.physicsBody?.isDynamic = false
        floor.physicsBody?.categoryBitMask = HalfCourtPhysicsCategory.court
        floor.physicsBody?.restitution = 0.5
        courtLayer.addChild(floor)

        // Court floor surface (wooden look)
        let court = SKShapeNode(rectOf: CGSize(width: size.width, height: 340))
        court.fillColor = SKColor(red: 0.78, green: 0.53, blue: 0.24, alpha: 1.0)
        court.strokeColor = .clear
        court.position = CGPoint(x: size.width / 2, y: floorY + 170)
        courtLayer.addChild(court)

        // Wood grain lines
        for i in 0..<18 {
            let line = SKShapeNode()
            let path = CGMutablePath()
            let y = floorY + CGFloat(i) * 20
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            line.path = path
            line.strokeColor = SKColor(red: 0.62, green: 0.42, blue: 0.16, alpha: 0.35)
            line.lineWidth = 1
            courtLayer.addChild(line)
        }

        // Paint (key) area — near basket on floor surface
        let paintW: CGFloat = 200
        let paint = SKShapeNode(rectOf: CGSize(width: paintW, height: 4))
        paint.fillColor = SKColor(red: 0.22, green: 0.52, blue: 0.82, alpha: 0.8)
        paint.strokeColor = .clear
        paint.position = CGPoint(x: size.width - paintW / 2, y: floorY + 4)
        courtLayer.addChild(paint)

        // Three-point line (side-view: vertical line on the court floor)
        let tpX: CGFloat = hchRimX - 300
        let tpLine = makeCourtLine(
            from: CGPoint(x: tpX, y: floorY + 2),
            to: CGPoint(x: tpX, y: floorY + 18))
        courtLayer.addChild(tpLine)

        // "3PT" label at the line
        let tpLabel = SKLabelNode(text: "3PT")
        tpLabel.fontName = "AvenirNext-Bold"
        tpLabel.fontSize = 11
        tpLabel.fontColor = SKColor.white.withAlphaComponent(0.5)
        tpLabel.horizontalAlignmentMode = .center
        tpLabel.position = CGPoint(x: tpX, y: floorY + 22)
        courtLayer.addChild(tpLabel)

        // Free throw line
        let ftX: CGFloat = hchRimX - 180
        let ftLine = makeCourtLine(
            from: CGPoint(x: ftX, y: floorY + 2),
            to: CGPoint(x: ftX, y: floorY + 14))
        courtLayer.addChild(ftLine)

        // Backboard
        let backboard = SKShapeNode(rectOf: CGSize(width: 8, height: 90))
        backboard.fillColor = SKColor(red: 0.88, green: 0.88, blue: 0.92, alpha: 0.9)
        backboard.strokeColor = SKColor.white.withAlphaComponent(0.6)
        backboard.lineWidth = 1.5
        backboard.position = CGPoint(x: hchRimX + hchRimR + 14, y: hchRimY + 20)
        backboard.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: 8, height: 90))
        backboard.physicsBody?.isDynamic = false
        backboard.physicsBody?.categoryBitMask = HalfCourtPhysicsCategory.rim
        backboard.physicsBody?.restitution = 0.25
        courtLayer.addChild(backboard)

        // Backboard support pole
        let pole = SKShapeNode()
        let polePath = CGMutablePath()
        polePath.move(to: CGPoint(x: hchRimX + hchRimR + 18, y: hchRimY - 30))
        polePath.addLine(to: CGPoint(x: hchRimX + hchRimR + 18, y: floorY))
        pole.path = polePath
        pole.strokeColor = SKColor(red: 0.5, green: 0.5, blue: 0.55, alpha: 0.8)
        pole.lineWidth = 6
        pole.lineCap = .round
        courtLayer.addChild(pole)

        // Rim
        let rim = SKShapeNode(rectOf: CGSize(width: hchRimR * 2, height: 8))
        rim.fillColor = .orange
        rim.strokeColor = SKColor(red: 0.8, green: 0.35, blue: 0.0, alpha: 1.0)
        rim.lineWidth = 1.5
        rim.position = CGPoint(x: hchRimX, y: hchRimY)
        rim.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: hchRimR * 2, height: 8))
        rim.physicsBody?.isDynamic = false
        rim.physicsBody?.categoryBitMask = HalfCourtPhysicsCategory.rim
        rim.physicsBody?.restitution = 0.45
        courtLayer.addChild(rim)

        // Net (visual only — drawn as lines)
        for i in 0..<6 {
            let netLine = SKShapeNode()
            let netPath = CGMutablePath()
            let x = hchRimX - hchRimR + CGFloat(i) * (hchRimR * 2 / 5)
            netPath.move(to: CGPoint(x: x, y: hchRimY - 4))
            netPath.addLine(to: CGPoint(x: x + 4, y: hchRimY - 40))
            netLine.path = netPath
            netLine.strokeColor = SKColor.white.withAlphaComponent(0.7)
            netLine.lineWidth = 1.2
            courtLayer.addChild(netLine)
        }
        for j in 0...2 {
            let crossLine = SKShapeNode()
            let crossPath = CGMutablePath()
            let y = hchRimY - 12 - CGFloat(j) * 10
            crossPath.move(to: CGPoint(x: hchRimX - hchRimR + 2, y: y))
            crossPath.addLine(to: CGPoint(x: hchRimX + hchRimR - 2, y: y - 2))
            crossLine.path = crossPath
            crossLine.strokeColor = SKColor.white.withAlphaComponent(0.45)
            crossLine.lineWidth = 1
            courtLayer.addChild(crossLine)
        }

        // Invisible net physics sensor
        let netSensor = SKShapeNode(rectOf: CGSize(width: hchRimR * 1.5, height: 10))
        netSensor.position = CGPoint(x: hchRimX, y: hchRimY - 24)
        netSensor.alpha = 0
        netSensor.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: hchRimR * 1.5, height: 10))
        netSensor.physicsBody?.isDynamic = false
        netSensor.physicsBody?.categoryBitMask = HalfCourtPhysicsCategory.net
        netSensor.physicsBody?.contactTestBitMask = HalfCourtPhysicsCategory.ball
        netSensor.physicsBody?.collisionBitMask = 0
        courtLayer.addChild(netSensor)
    }

    private func makeCourtLine(from: CGPoint, to: CGPoint) -> SKShapeNode {
        let node = SKShapeNode()
        let path = CGMutablePath()
        path.move(to: from)
        path.addLine(to: to)
        node.path = path
        node.strokeColor = SKColor.white.withAlphaComponent(0.55)
        node.lineWidth = 2.5
        return node
    }
    
    private func setupPhysics() {
        physicsWorld.gravity = CGVector(dx: 0, dy: -20)
        physicsWorld.contactDelegate = self
    }
    
    private func setupMotion() {
        guard motion.isDeviceMotionAvailable else { return }
        motion.deviceMotionUpdateInterval = 1.0 / 60.0
        motion.startDeviceMotionUpdates()
    }
    
    // MARK: - Loop
    override func update(_ currentTime: TimeInterval) {
        let dt = lastUpdate.map { currentTime - $0 } ?? 0.016
        lastUpdate = currentTime
        
        guard phase == .playing else {
            hud?.isHidden = true
            shootButton?.isHidden = true
            return
        }
        hud?.isHidden = false
        shootButton?.isHidden = possession != .home || ballInAir

        updateAI(dt: dt)
        updateShotClock()
        updateMotion()

        hud?.update(
            homeScore: homeScore,
            awayScore: awayScore,
            homeWins: homeSeriesWins,
            awayWins: awaySeriesWins,
            shotClock: Int(ceil(Double(shotClockFrames) / 60.0))
        )
    }
    
    private func updateAI(dt: TimeInterval) {
        for (id, player) in players {
            if player.team == .away {
                if possession == .home {
                    if let targetID = activeHumanID, let human = players[targetID] {
                        let basketPos = CGPoint(x: hchRimX, y: 150)
                        let defendPos = CGPoint(x: (human.position.x + basketPos.x) / 2, y: human.position.y)
                        movePlayer(player, toward: defendPos, dt: dt)
                    }
                }
            }
        }
    }
    
    private func movePlayer(_ player: PlayerNode, toward target: CGPoint, dt: TimeInterval) {
        let dx = target.x - player.position.x
        let dy = target.y - player.position.y
        let dist = hypot(dx, dy)
        if dist > 10 {
            let speed: CGFloat = 180 * CGFloat(dt)
            player.position.x += (dx / dist) * speed
            player.position.y += (dy / dist) * speed
            player.facing = dx > 0 ? 1 : -1
        }
    }
    
    private func updateShotClock() {
        if possession == .home && !ballInAir {
            shotClockFrames = max(0, shotClockFrames - 1)
            if shotClockFrames == 0 {
                possession = .away
                shotClockFrames = 600
            }
        } else {
            shotClockFrames = 600
        }
    }
    
    private func updateMotion() {
        guard let data = motion.deviceMotion else { return }
        let tiltX = CGFloat(data.attitude.roll * 20)
        let tiltY = CGFloat((data.attitude.pitch - .pi / 2) * 15)
        worldNode.position = CGPoint(x: tiltX, y: tiltY)
    }
    
    private var ballInAir: Bool {
        ball?.physicsBody?.isDynamic ?? false && (ball?.position.y ?? 0) > 120
    }
    
    // MARK: - Match Management
    func startSeries() {
        homeSeriesWins = 0
        awaySeriesWins = 0
        phase = .characterSelect
    }
    
    func startGame(playerID: HalfCourtHeroID, teammateID: HalfCourtHeroID) {
        homeIDs = [playerID, teammateID]
        awayIDs = HalfCourtHeroID.allCases.filter { !homeIDs.contains($0) }
        activeHumanID = playerID
        
        homeScore = 0
        awayScore = 0
        resetMatch()
        phase = .playing
    }
    
    private func resetMatch() {
        playersLayer.removeAllChildren()
        ballLayer.removeAllChildren()
        players.removeAll()
        resultCard?.removeFromParent()
        resultCard = nil
        
        for (i, id) in homeIDs.enumerated() {
            spawnPlayer(id: id, team: .home, pos: CGPoint(x: 150 + CGFloat(i * 100), y: 150))
        }
        for (i, id) in awayIDs.enumerated() {
            spawnPlayer(id: id, team: .away, pos: CGPoint(x: 500 + CGFloat(i * 100), y: 150))
        }
        
        spawnBall(at: CGPoint(x: 150, y: 300))
        possession = .home
        players[homeIDs[0]]?.setSelectionActive(true)
        shotClockFrames = 600
    }
    
    private func spawnPlayer(id: HalfCourtHeroID, team: HalfCourtTeam, pos: CGPoint) {
        let node = PlayerNode(heroID: id, team: team)
        node.position = pos
        playersLayer.addChild(node)
        players[id] = node
    }
    
    private func spawnBall(at pos: CGPoint) {
        let node = BallNode()
        node.position = pos
        ballLayer.addChild(node)
        ball = node
    }
    
    // MARK: - Interaction
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }

        if phase == .ended {
            _ = resultCard?.handleTouch(touch)
            return
        }

        guard phase == .playing else { return }

        // Check shoot button in uiLayer first
        let uiLocation = touch.location(in: uiLayer)
        if let btn = shootButton, !btn.isHidden,
           btn.frame.insetBy(dx: -20, dy: -20).contains(uiLocation) {
            shootBall()
            HapticManager.impact(.medium)
            return
        }

        // Otherwise move the active player
        if possession == .home, let activeID = activeHumanID, let player = players[activeID] {
            let courtLocation = touch.location(in: courtLayer)
            movePlayer(player, toward: courtLocation, dt: 0.1)
        }
    }

    func shootBall() {
        guard let ball = ball, possession == .home else { return }
        let dx = hchRimX - ball.position.x
        let dy = hchRimY - ball.position.y
        let distance = hypot(dx, dy)
        let power: CGFloat = max(18, min(32, distance * 0.04))
        let impulse = CGVector(
            dx: dx * 0.048 * power,
            dy: (dy + 380 + distance * 0.12) * 0.048 * power
        )
        ball.physicsBody?.applyImpulse(impulse)
        possession = .away
        shootButton?.flash()
    }
    
    // MARK: - SKPhysicsContactDelegate
    func didBegin(_ contact: SKPhysicsContact) {
        let collision = contact.bodyA.categoryBitMask | contact.bodyB.categoryBitMask
        if collision == (HalfCourtPhysicsCategory.ball | HalfCourtPhysicsCategory.net) {
            handleScore()
        }
    }
    
    private func handleScore() {
        guard let ball = ball, ball.physicsBody!.velocity.dy < 0 else { return }
        if possession == .home { homeScore += 2 } else { awayScore += 2 }
        HapticManager.notification(.success)
        checkWinCondition()
    }
    
    private func checkWinCondition() {
        let winScore = 11
        if homeScore >= winScore {
            homeSeriesWins += 1
            resolveGame()
        } else if awayScore >= winScore {
            awaySeriesWins += 1
            resolveGame()
        } else {
            ball?.physicsBody?.velocity = .zero
            ball?.position = CGPoint(x: 200, y: 400)
            possession = (possession == .home) ? .away : .home
        }
    }
    
    private func resolveGame() {
        let isSeriesOver = homeSeriesWins >= seriesWinTarget || awaySeriesWins >= seriesWinTarget
        let card = HalfCourtResultCardNode(
            homeWins: homeSeriesWins,
            awayWins: awaySeriesWins,
            isSeriesOver: isSeriesOver,
            onAction: { [weak self] in
                if isSeriesOver { self?.onDismiss?() }
                else { self?.homeScore = 0; self?.awayScore = 0; self?.resetMatch() }
            }
        )
        card.position = CGPoint(x: size.width / 2, y: size.height / 2)
        uiLayer.addChild(card)
        resultCard = card
        phase = .ended
    }
}

// MARK: - Shoot Button

@MainActor
final class ShootButtonNode: SKNode {
    private let ring = SKShapeNode(circleOfRadius: 56)
    private let innerRing = SKShapeNode(circleOfRadius: 46)
    private let label = SKLabelNode(text: "SHOOT")
    private let ballIcon = SKShapeNode(circleOfRadius: 14)

    override init() {
        super.init()
        setup()
    }

    required init?(coder aDecoder: NSCoder) { fatalError() }

    private func setup() {
        ring.fillColor = SKColor(red: 1.0, green: 0.08, blue: 0.58, alpha: 0.18)
        ring.strokeColor = SKColor(red: 1.0, green: 0.08, blue: 0.58, alpha: 0.85)
        ring.lineWidth = 3
        addChild(ring)

        innerRing.fillColor = .clear
        innerRing.strokeColor = SKColor(red: 1.0, green: 0.08, blue: 0.58, alpha: 0.32)
        innerRing.lineWidth = 1.5
        addChild(innerRing)

        ballIcon.fillColor = SKColor(red: 0.85, green: 0.42, blue: 0.11, alpha: 0.9)
        ballIcon.strokeColor = SKColor(red: 0.6, green: 0.25, blue: 0.05, alpha: 0.8)
        ballIcon.lineWidth = 1.5
        ballIcon.position = CGPoint(x: 0, y: 14)
        addChild(ballIcon)

        label.fontName = "AvenirNext-Bold"
        label.fontSize = 13
        label.fontColor = SKColor(red: 1.0, green: 0.08, blue: 0.58, alpha: 0.9)
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: 0, y: -22)
        addChild(label)

        // Pulse animation
        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.06, duration: 0.7),
            SKAction.scale(to: 0.96, duration: 0.7)
        ])
        ring.run(SKAction.repeatForever(pulse))
    }

    func flash() {
        let flash = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.3, duration: 0.06),
            SKAction.fadeAlpha(to: 1.0, duration: 0.14)
        ])
        run(flash)
    }
}
