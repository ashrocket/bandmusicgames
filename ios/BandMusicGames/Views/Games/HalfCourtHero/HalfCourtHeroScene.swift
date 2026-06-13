import SpriteKit
import Combine

/// Half Court Hero — side-view streetball in Nara's room.
///
/// Layout fills the actual device screen (`.resizeFill`); all court geometry is
/// derived from `size`, so the hoop, button, and court are never cropped.
///
/// Controls: touch anywhere to summon a movement joystick; press and hold the
/// SHOOT button to charge the meter, release in the green to cash.
/// Releasing on the song's beat 3 shots in a row (make or miss) lights you ON FIRE:
/// boosted accuracy and +1 on every make while it lasts.
@MainActor
final class HalfCourtHeroScene: SKScene, ObservableObject, SKPhysicsContactDelegate {

    // MARK: - Tuning
    private let seriesWinTarget = 3
    private let winScore = 11
    private let beatBPM: Double = 112          // Nara's Room tempo — tune to taste
    private let onBeatWindow: TimeInterval = 0.14
    private let powerUpDuration: TimeInterval = 12
    private var shotClockSeconds: TimeInterval = 10
    private var chargeRate: CGFloat = 1.55
    private var greenLow: CGFloat = 0.52
    private var greenHigh: CGFloat = 0.76
    private var perfectLow: CGFloat = 0.59
    private var perfectHigh: CGFloat = 0.69
    private var cpuShotMult: CGFloat = 1.0
    private let shootWindupDelay: TimeInterval = 0.29  // ball leaves hand 4 frames into the 14fps shoot anim

    // MARK: - Layout metrics (recomputed from `size`)
    private var floorY: CGFloat = 100
    private var courtBandMinY: CGFloat = 70
    private var courtBandMaxY: CGFloat = 144
    private var rimX: CGFloat = 330
    private var rimY: CGFloat = 480
    private let rimR: CGFloat = 24
    private var threePointX: CGFloat = 120
    private var playerMinX: CGFloat = 30
    private var playerMaxX: CGFloat = 280
    private var playerSpriteSize: CGFloat = 112

    // MARK: - Nodes
    private let courtLayer = SKNode()
    private let playersLayer = SKNode()
    private let ballLayer = SKNode()
    private let fxLayer = SKNode()
    private let uiLayer = SKNode()

    private var ball: BallNode?
    private var players: [HalfCourtHeroID: PlayerNode] = [:]
    private var hud: HalfCourtHUDNode?
    private var resultCard: HalfCourtResultCardNode?
    private var shootButton: ShootButtonNode?
    private var stormSky: StormSkyNode?
    private var joystick: JoystickNode?
    private var streakPips: StreakPipsNode?
    private var calloutNode: SKNode?
    private var rimNode: SKShapeNode?
    private var ballTrailActive = false
    private var trailFrameCounter = 0

    var onDismiss: (() -> Void)?

    // MARK: - Match state
    @Published private(set) var phase: HalfCourtPhase = .title
    @Published private(set) var difficulty: HalfCourtDifficulty = .normal
    @Published var homeScore = 0
    @Published var awayScore = 0
    @Published var homeSeriesWins = 0
    @Published var awaySeriesWins = 0

    private enum PlayState {
        case homeLive   // human has the ball
        case homeShot   // human shot in windup or flight
        case awayLive   // CPU has the ball
        case awayShot   // CPU shot in windup or flight
    }

    private enum CPUState {
        case idle
        case bringUp(CGPoint)
        case dribbling(TimeInterval)
        case shooting
    }

    private struct PendingLaunch {
        let at: TimeInterval
        let team: HalfCourtTeam
        let errorOffset: CGFloat
    }

    private var homeIDs: [HalfCourtHeroID] = []
    private var awayIDs: [HalfCourtHeroID] = []
    private var activeHumanID: HalfCourtHeroID?
    private var cpuHandlerID: HalfCourtHeroID?
    private var possession: HalfCourtTeam = .home
    private var playState: PlayState = .homeLive
    private var cpuState: CPUState = .idle
    private var shotClockRemaining: TimeInterval = 10
    private var lastUpdate: TimeInterval?
    private var nowTime: TimeInterval = 0

    // Touch routing
    private var shootTouch: UITouch?
    private var joystickTouch: UITouch?
    private var chargeActive = false
    private var charge: CGFloat = 0

    // Beat + power-up
    private var beatAnchor: TimeInterval?
    private var lastBeatIndex = -1
    private var onBeatStreak = 0
    private var poweredUntil: TimeInterval = 0
    private var isPowered = false

    // Deferred state transitions (driven from update(), not action closures)
    private var pendingLaunch: PendingLaunch?
    private var pendingPossession: HalfCourtTeam?
    private var pendingPossessionAt: TimeInterval = 0
    private var pendingResolveAt: TimeInterval?
    private var shotDeadline: TimeInterval = .infinity
    private var stealCooldownUntil: TimeInterval = 0
    private var humanStealCooldownUntil: TimeInterval = 0

    // MARK: - Construction
    static func make() -> HalfCourtHeroScene {
        let scene = HalfCourtHeroScene(size: UIScreen.main.bounds.size)
        scene.scaleMode = .resizeFill
        scene.backgroundColor = SKColor(red: 0.1, green: 0.04, blue: 0.24, alpha: 1) // 1a0a3e
        return scene
    }

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        view.isMultipleTouchEnabled = true

        if courtLayer.parent == nil {
            addChild(courtLayer)
            addChild(playersLayer)
            addChild(ballLayer)
            addChild(fxLayer)
            addChild(uiLayer)
        }

        if hud == nil {
            let hudNode = HalfCourtHUDNode(size: size)
            hudNode.zPosition = 100
            uiLayer.addChild(hudNode)
            hud = hudNode
        }

        if shootButton == nil {
            let btn = ShootButtonNode(greenLow: greenLow, greenHigh: greenHigh,
                                      perfectLow: perfectLow, perfectHigh: perfectHigh)
            btn.zPosition = 110
            btn.isHidden = true
            uiLayer.addChild(btn)
            shootButton = btn
        }

        if streakPips == nil {
            let pips = StreakPipsNode()
            pips.zPosition = 110
            pips.isHidden = true
            uiLayer.addChild(pips)
            streakPips = pips
        }

        if joystick == nil {
            let stick = JoystickNode()
            stick.zPosition = 120
            stick.isHidden = true
            uiLayer.addChild(stick)
            joystick = stick
        }

        physicsWorld.gravity = CGVector(dx: 0, dy: -9.0)
        physicsWorld.contactDelegate = self

        layoutScene()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard view != nil, size.width > 50, size.height > 50 else { return }
        layoutScene()
    }

    // MARK: - Layout

    private func layoutScene() {
        let w = size.width
        let h = size.height

        floorY = max(70, h * 0.12)
        courtBandMinY = max(44, h * 0.055)
        courtBandMaxY = h * 0.30
        rimX = w - 58
        rimY = h * 0.62
        threePointX = rimX - w * 0.56
        playerMinX = 44
        playerMaxX = rimX - 56
        playerSpriteSize = min(210, max(140, h * 0.215))

        buildCourt()
        hud?.layout(size: size)
        shootButton?.position = CGPoint(x: w - 82, y: 112)
        streakPips?.position = CGPoint(x: w - 82, y: 112 + 84)
        resultCard?.position = CGPoint(x: w / 2, y: h / 2)

        for player in players.values {
            clampToCourt(player)
        }
    }

    private func buildCourt() {
        courtLayer.removeAllChildren()
        let w = size.width

        // Painted streetball backdrop (same art as the web game)
        if UIImage(named: "hch_court") != nil {
            let bgTexture = SKTexture(imageNamed: "hch_court")
            bgTexture.filteringMode = .linear
            let bg = SKSpriteNode(texture: bgTexture)
            let scale = max(w / max(bgTexture.size().width, 1), size.height / max(bgTexture.size().height, 1))
            bg.size = CGSize(width: bgTexture.size().width * scale, height: bgTexture.size().height * scale)
            bg.position = CGPoint(x: w / 2, y: size.height / 2)
            bg.zPosition = -10
            courtLayer.addChild(bg)
        } else {
            // Fallback if the asset is missing: plain asphalt band
            let asphalt = SKShapeNode(rect: CGRect(x: 0, y: 0, width: w, height: courtBandMaxY + 80))
            asphalt.fillColor = SKColor(red: 0.32, green: 0.34, blue: 0.38, alpha: 1)
            asphalt.strokeColor = .clear
            courtLayer.addChild(asphalt)
        }

        // Storm sky — charge-meter weather. Above backdrop, below players.
        let storm = StormSkyNode(size: size,
                                 greenLow: greenLow, greenHigh: greenHigh,
                                 perfectLow: perfectLow, perfectHigh: perfectHigh)
        storm.zPosition = -5
        courtLayer.addChild(storm)
        stormSky = storm
        storm.prime(charge: chargeActive ? charge : nil)

        // Three-point marker
        let tpLine = SKShapeNode()
        let tpPath = CGMutablePath()
        tpPath.move(to: CGPoint(x: threePointX, y: 6))
        tpPath.addLine(to: CGPoint(x: threePointX, y: courtBandMaxY + 24))
        tpLine.path = tpPath
        tpLine.strokeColor = SKColor.white.withAlphaComponent(0.28)
        tpLine.lineWidth = 2
        courtLayer.addChild(tpLine)

        let tpLabel = SKLabelNode(text: "3PT")
        tpLabel.fontName = "AvenirNext-Bold"
        tpLabel.fontSize = 10
        tpLabel.fontColor = SKColor.white.withAlphaComponent(0.45)
        tpLabel.position = CGPoint(x: threePointX, y: courtBandMaxY + 32)
        courtLayer.addChild(tpLabel)

        // Backboard
        let boardX = rimX + rimR + 11
        let backboard = SKShapeNode(rectOf: CGSize(width: 6, height: 76))
        backboard.fillColor = SKColor(red: 0.88, green: 0.88, blue: 0.92, alpha: 0.9)
        backboard.strokeColor = SKColor.white.withAlphaComponent(0.6)
        backboard.lineWidth = 1.5
        backboard.position = CGPoint(x: boardX, y: rimY + 26)
        backboard.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: 6, height: 76))
        backboard.physicsBody?.isDynamic = false
        backboard.physicsBody?.categoryBitMask = HalfCourtPhysicsCategory.rim
        backboard.physicsBody?.restitution = 0.3
        courtLayer.addChild(backboard)

        // Support pole
        let pole = SKShapeNode()
        let polePath = CGMutablePath()
        polePath.move(to: CGPoint(x: boardX + 4, y: rimY - 12))
        polePath.addLine(to: CGPoint(x: boardX + 4, y: courtBandMaxY - 12))
        pole.path = polePath
        pole.strokeColor = SKColor(red: 0.5, green: 0.5, blue: 0.55, alpha: 0.8)
        pole.lineWidth = 6
        pole.lineCap = .round
        courtLayer.addChild(pole)

        // Rim — visual bar, but physics is only the two lips so the ball can drop through
        let rimVisual = SKShapeNode(rectOf: CGSize(width: rimR * 2, height: 5), cornerRadius: 2.5)
        rimVisual.fillColor = .orange
        rimVisual.strokeColor = SKColor(red: 0.8, green: 0.35, blue: 0.0, alpha: 1.0)
        rimVisual.lineWidth = 1.5
        rimVisual.position = CGPoint(x: rimX, y: rimY)
        courtLayer.addChild(rimVisual)
        rimNode = rimVisual

        for lipX in [rimX - rimR, rimX + rimR] {
            let lip = SKNode()
            lip.position = CGPoint(x: lipX, y: rimY)
            let body = SKPhysicsBody(circleOfRadius: 3.5)
            body.isDynamic = false
            body.categoryBitMask = HalfCourtPhysicsCategory.rim
            body.restitution = 0.5
            lip.physicsBody = body
            courtLayer.addChild(lip)
        }

        // Net (visual)
        for i in 0..<6 {
            let netLine = SKShapeNode()
            let netPath = CGMutablePath()
            let x = rimX - rimR + 3 + CGFloat(i) * ((rimR * 2 - 6) / 5)
            netPath.move(to: CGPoint(x: x, y: rimY - 3))
            netPath.addLine(to: CGPoint(x: rimX + (x - rimX) * 0.6, y: rimY - 30))
            netLine.path = netPath
            netLine.strokeColor = SKColor.white.withAlphaComponent(0.7)
            netLine.lineWidth = 1.2
            courtLayer.addChild(netLine)
        }

        // Net score sensor
        let netSensor = SKNode()
        netSensor.position = CGPoint(x: rimX, y: rimY - 20)
        let sensorBody = SKPhysicsBody(rectangleOf: CGSize(width: rimR * 1.2, height: 6))
        sensorBody.isDynamic = false
        sensorBody.categoryBitMask = HalfCourtPhysicsCategory.net
        sensorBody.contactTestBitMask = HalfCourtPhysicsCategory.ball
        sensorBody.collisionBitMask = 0
        netSensor.physicsBody = sensorBody
        courtLayer.addChild(netSensor)

        // Ball floor plane + side walls keep the ball on screen
        let floorNode = SKNode()
        let floorBody = SKPhysicsBody(edgeFrom: CGPoint(x: -60, y: floorY), to: CGPoint(x: w + 60, y: floorY))
        floorBody.categoryBitMask = HalfCourtPhysicsCategory.court
        floorBody.contactTestBitMask = HalfCourtPhysicsCategory.ball
        floorBody.restitution = 0.5
        floorBody.friction = 0.4
        floorNode.physicsBody = floorBody
        courtLayer.addChild(floorNode)

        for wallX in [CGFloat(3), w - 2] {
            let wall = SKNode()
            let wallBody = SKPhysicsBody(edgeFrom: CGPoint(x: wallX, y: floorY), to: CGPoint(x: wallX, y: size.height + 200))
            wallBody.categoryBitMask = HalfCourtPhysicsCategory.court
            wallBody.restitution = 0.35
            wall.physicsBody = wallBody
            courtLayer.addChild(wall)
        }
    }

    // MARK: - Match management

    func startSeries() {
        homeSeriesWins = 0
        awaySeriesWins = 0
        phase = .characterSelect
    }

    func startGame(playerID: HalfCourtHeroID, teammateID: HalfCourtHeroID, difficulty: HalfCourtDifficulty = .normal) {
        self.difficulty = difficulty
        let d = difficulty
        greenLow = d.greenWindow.low / 100
        greenHigh = d.greenWindow.high / 100
        let mid = (greenLow + greenHigh) / 2
        perfectLow = mid - 0.05
        perfectHigh = mid + 0.05
        chargeRate = d.chargeRate
        cpuShotMult = d.cpuShotMultiplier
        shotClockSeconds = d.shotClockSeconds

        shootButton?.reconfigureArcs(greenLow: greenLow, greenHigh: greenHigh,
                                      perfectLow: perfectLow, perfectHigh: perfectHigh)

        homeIDs = [playerID, teammateID]
        awayIDs = HalfCourtHeroID.allCases.filter { !homeIDs.contains($0) }
        activeHumanID = playerID

        homeScore = 0
        awayScore = 0
        beatAnchor = nil
        lastBeatIndex = -1
        onBeatStreak = 0
        poweredUntil = 0
        isPowered = false
        stealCooldownUntil = 0
        humanStealCooldownUntil = 0
        resetMatch()
        phase = .playing
    }

    private func resetMatch() {
        playersLayer.removeAllChildren()
        ballLayer.removeAllChildren()
        players.removeAll()
        resultCard?.removeFromParent()
        resultCard = nil
        pendingLaunch = nil
        pendingPossession = nil
        pendingResolveAt = nil
        shotDeadline = .infinity
        streakPips?.set(count: 0, powered: false)

        let bandMid = (courtBandMinY + courtBandMaxY) / 2
        if let humanID = activeHumanID {
            spawnPlayer(id: humanID, team: .home, pos: CGPoint(x: size.width * 0.32, y: bandMid))
        }
        if let mateID = homeIDs.first(where: { $0 != activeHumanID }) {
            spawnPlayer(id: mateID, team: .home, pos: CGPoint(x: max(playerMinX + 20, threePointX * 0.4), y: courtBandMaxY - 6))
        }
        for (i, id) in awayIDs.enumerated() {
            spawnPlayer(id: id, team: .away,
                        pos: CGPoint(x: rimX - 70 - CGFloat(i) * 80, y: bandMid + CGFloat(i) * 22 - 8))
        }

        let ballNode = BallNode()
        ballNode.zPosition = 70
        ballLayer.addChild(ballNode)
        ball = ballNode

        if let humanID = activeHumanID {
            players[humanID]?.setSelectionActive(true)
        }
        givePossession(to: .home)
    }

    private func spawnPlayer(id: HalfCourtHeroID, team: HalfCourtTeam, pos: CGPoint) {
        let node = PlayerNode(heroID: id, team: team, spriteSize: playerSpriteSize)
        node.position = pos
        clampToCourt(node)
        playersLayer.addChild(node)
        players[id] = node
    }

    // MARK: - Possession flow

    private func givePossession(to team: HalfCourtTeam) {
        guard phase == .playing else { return }
        possession = team
        pendingLaunch = nil
        shotDeadline = .infinity
        ballTrailActive = false
        ball?.hold()
        ball?.setOnFire(false)
        shotClockRemaining = shotClockSeconds

        if team == .home {
            playState = .homeLive
            cpuState = .idle
        } else {
            playState = .awayLive
            cpuHandlerID = awayIDs.randomElement()
            cpuState = .bringUp(pickCPUSpot())
            cancelCharge()
        }
    }

    private func scheduleGivePossession(to team: HalfCourtTeam, after delay: TimeInterval) {
        pendingPossession = team
        pendingPossessionAt = nowTime + delay
    }

    private func pickCPUSpot() -> CGPoint {
        let minX = max(threePointX - 64, playerMinX + 12)
        let maxX = max(minX + 20, rimX - 130)
        return CGPoint(
            x: CGFloat.random(in: minX...maxX),
            y: CGFloat.random(in: courtBandMinY...courtBandMaxY)
        )
    }

    // MARK: - Update loop

    override func update(_ currentTime: TimeInterval) {
        nowTime = currentTime
        let rawDt = lastUpdate.map { currentTime - $0 } ?? 1.0 / 60.0
        let dt = CGFloat(min(max(rawDt, 0), 1.0 / 20.0))
        lastUpdate = currentTime

        guard phase == .playing else {
            hud?.isHidden = true
            shootButton?.isHidden = true
            streakPips?.isHidden = true
            joystick?.end()
            return
        }
        hud?.isHidden = false
        shootButton?.isHidden = false
        streakPips?.isHidden = false

        updateBeat(currentTime)
        updatePowerState(currentTime)
        firePendingTransitions(currentTime)
        updateCharge(dt)
        updateHuman(dt)
        updateCPU(dt: dt, now: currentTime)
        updateOffBall(dt: dt)
        updateBallCarry(currentTime)
        updateBallTrail()
        updateShotClock(dt: TimeInterval(dt))
        resolveExpiredFlight(currentTime)
        for player in players.values {
            player.tick(now: currentTime)
        }
        updateDepthSorting()

        shootButton?.setEnabled(playState == .homeLive || playState == .awayLive)
        shootButton?.setMode(stealing: playState == .awayLive)
        hud?.update(
            homeScore: homeScore,
            awayScore: awayScore,
            homeWins: homeSeriesWins,
            awayWins: awaySeriesWins,
            shotClock: playState == .homeLive ? Int(ceil(shotClockRemaining)) : 0,
            powered: isPowered,
            powerRemaining: max(0, Int(ceil(poweredUntil - currentTime)))
        )
    }

    private func updateBeat(_ now: TimeInterval) {
        if beatAnchor == nil {
            beatAnchor = now
            lastBeatIndex = 0
        }
        guard let anchor = beatAnchor else { return }
        let interval = 60.0 / beatBPM
        let idx = Int(((now - anchor) / interval).rounded(.down))
        if idx > lastBeatIndex {
            lastBeatIndex = idx
            shootButton?.beatPulse()
            if playState == .homeLive {
                HapticManager.selection()
            }
        }
    }

    private func nearestBeatDelta(_ now: TimeInterval) -> TimeInterval {
        guard let anchor = beatAnchor else { return .infinity }
        let interval = 60.0 / beatBPM
        let phase = (now - anchor).truncatingRemainder(dividingBy: interval)
        return min(phase, interval - phase)
    }

    private func updatePowerState(_ now: TimeInterval) {
        let powered = now < poweredUntil
        guard powered != isPowered else { return }
        isPowered = powered
        if let id = activeHumanID {
            players[id]?.setOnFire(powered)
        }
        if !powered {
            showCallout("COOLED OFF", color: SKColor.white.withAlphaComponent(0.7))
            streakPips?.set(count: onBeatStreak, powered: false)
        }
    }

    private func firePendingTransitions(_ now: TimeInterval) {
        if let launch = pendingLaunch, now >= launch.at {
            pendingLaunch = nil
            performLaunch(launch)
        }
        if let team = pendingPossession, now >= pendingPossessionAt {
            pendingPossession = nil
            givePossession(to: team)
        }
        if let resolveAt = pendingResolveAt, now >= resolveAt {
            pendingResolveAt = nil
            resolveGame()
        }
    }

    private func updateCharge(_ dt: CGFloat) {
        guard chargeActive else { return }
        guard playState == .homeLive else {
            cancelCharge()
            return
        }
        charge = min(charge + chargeRate * dt, 1.18)
        shootButton?.setCharge(charge)
        stormSky?.setCharge(charge)
    }

    private func cancelCharge() {
        chargeActive = false
        charge = 0
        shootButton?.setCharge(nil)
        stormSky?.setCharge(nil)
    }

    private func updateHuman(_ dt: CGFloat) {
        guard let id = activeHumanID, let player = players[id] else { return }
        let v = joystick?.vector ?? .zero
        let mag = hypot(v.dx, v.dy)
        var moving = false

        if mag > 0.14, playState == .homeLive || playState == .awayLive || playState == .awayShot {
            let speed = 250 * player.heroID.character.speed
            player.position.x += v.dx * speed * dt
            player.position.y += v.dy * 200 * dt
            clampToCourt(player)
            if abs(v.dx) > 0.1 {
                player.facing = v.dx > 0 ? 1 : -1
            }
            player.moveIntensity = min(1, mag * 1.2)
            moving = true
        }

        let hasBall = possession == .home && (ball?.isHeld ?? false)
        if !moving && hasBall {
            player.facing = 1 // square up to the hoop
        }
        player.updateLocomotion(moving: moving, hasBall: hasBall)
    }

    private func updateCPU(dt: CGFloat, now: TimeInterval) {
        guard playState == .awayLive,
              let id = cpuHandlerID,
              let handler = players[id] else { return }

        switch cpuState {
        case .bringUp(let spot):
            if !steer(handler, toward: spot, speed: 150 * difficulty.cpuDriveSpeed / 2.2, dt: dt) {
                cpuState = .dribbling(now + TimeInterval.random(in: 0.8...1.5))
            }
            handler.updateLocomotion(moving: true, hasBall: true)
        case .dribbling(let until):
            handler.facing = 1
            handler.updateLocomotion(moving: false, hasBall: true)
            if now >= until {
                cpuState = .shooting
                let dist = abs(rimX - handler.position.x)
                var error: CGFloat = (17 + dist * 0.05) * cpuShotMult
                if let humanID = activeHumanID, let human = players[humanID],
                   hypot(human.position.x - handler.position.x, human.position.y - handler.position.y) < 64 {
                    let lockdownBonus = humanID.character.stealBonus
                    error += 18 * (1 + lockdownBonus)
                    showCallout("CONTESTED!", color: SKColor(red: 0.2, green: 0.83, blue: 0.2, alpha: 1))
                }
                playState = .awayShot
                handler.playAnimationOnce(.shoot)
                pendingLaunch = PendingLaunch(
                    at: now + shootWindupDelay,
                    team: .away,
                    errorOffset: CGFloat.random(in: -error...error)
                )
            }
        case .shooting, .idle:
            break
        }
    }

    private func updateOffBall(dt: CGFloat) {
        let bandMid = (courtBandMinY + courtBandMaxY) / 2

        // Home teammate hangs out in the corner and cheers
        if let mateID = homeIDs.first(where: { $0 != activeHumanID }), let mate = players[mateID] {
            let spot = CGPoint(x: playerMinX + 16, y: courtBandMaxY - 4)
            let moved = steer(mate, toward: spot, speed: 110, dt: dt)
            mate.updateLocomotion(moving: moved, hasBall: false)
        }

        // Away players defend or space the floor
        for (i, awayID) in awayIDs.enumerated() {
            guard let defender = players[awayID] else { continue }
            if possession == .away && awayID == cpuHandlerID { continue } // handled in updateCPU

            var target = CGPoint(x: rimX - 60 - CGFloat(i) * 56, y: bandMid + 14)
            if possession == .home, i == 0,
               let humanID = activeHumanID, let human = players[humanID] {
                // Primary defender shades you toward the hoop, with a standoff
                target = CGPoint(
                    x: min(human.position.x + 84, rimX - 70),
                    y: (human.position.y + bandMid) / 2
                )
            }
            let moved = steer(defender, toward: target, speed: 125, dt: dt)
            defender.updateLocomotion(moving: moved, hasBall: false)
            if !moved, possession == .home, let humanID = activeHumanID, let human = players[humanID] {
                defender.facing = human.position.x > defender.position.x ? 1 : -1
            }
        }

        // CPU steal attempt: primary defender close to human ball-handler
        if possession == .home, playState == .homeLive, nowTime > stealCooldownUntil,
           let awayID = awayIDs.first, let defender = players[awayID],
           let humanID = activeHumanID, let human = players[humanID] {
            let dist = hypot(defender.position.x - human.position.x, defender.position.y - human.position.y)
            if dist < 44 {
                let stealChance = difficulty.cpuStealRate * dt
                if CGFloat.random(in: 0...1) < stealChance {
                    stealCooldownUntil = nowTime + 3.5
                    showCallout("STOLEN!", color: SKColor(red: 1, green: 0.35, blue: 0.3, alpha: 1))
                    HapticManager.notification(.error)
                    givePossession(to: .away)
                }
            }
        }
    }

    @discardableResult
    private func steer(_ player: PlayerNode, toward target: CGPoint, speed: CGFloat, dt: CGFloat) -> Bool {
        let dx = target.x - player.position.x
        let dy = target.y - player.position.y
        let dist = hypot(dx, dy)
        guard dist > 7 else { return false }
        let step = min(dist, speed * dt)
        player.position.x += dx / dist * step
        player.position.y += dy / dist * step
        clampToCourt(player)
        player.facing = dx >= 0 ? 1 : -1
        return true
    }

    private func clampToCourt(_ player: PlayerNode) {
        player.position.x = min(max(player.position.x, playerMinX), playerMaxX)
        player.position.y = min(max(player.position.y, courtBandMinY), courtBandMaxY)
    }

    private func updateBallCarry(_ now: TimeInterval) {
        guard let ball, ball.isHeld else { return }
        let holder: PlayerNode? = possession == .home
            ? activeHumanID.flatMap { players[$0] }
            : cpuHandlerID.flatMap { players[$0] }
        guard let holder else { return }

        let windingUp = (playState == .homeShot || playState == .awayShot)
        let local = windingUp
            ? holder.shotReleasePoint()
            : holder.ballCarryPoint(bouncePhase: CGFloat(now) * 7)
        let s = abs(holder.xScale)  // depth scale
        ball.position = CGPoint(x: holder.position.x + local.x * s, y: holder.position.y + local.y * s)
        ball.zPosition = holder.zPosition + 1
    }

    private func updateBallTrail() {
        guard ballTrailActive, let ball, !ball.isHeld else { return }
        trailFrameCounter += 1
        guard trailFrameCounter % 2 == 0 else { return }

        let dot = SKShapeNode(circleOfRadius: 7)
        dot.fillColor = SKColor(red: 1, green: 0.55, blue: 0.1, alpha: 0.5)
        dot.strokeColor = .clear
        dot.position = ball.position
        dot.zPosition = 65
        fxLayer.addChild(dot)
        dot.run(SKAction.sequence([
            SKAction.group([
                SKAction.fadeOut(withDuration: 0.35),
                SKAction.scale(to: 0.2, duration: 0.35),
            ]),
            SKAction.removeFromParent(),
        ]))
    }

    private func shakeWorld(_ amplitude: CGFloat) {
        var steps: [SKAction] = []
        for i in 0..<6 {
            let decay = amplitude * (1 - CGFloat(i) / 6)
            steps.append(SKAction.moveBy(
                x: CGFloat.random(in: -decay...decay),
                y: CGFloat.random(in: -decay...decay),
                duration: 0.04
            ))
        }
        steps.append(SKAction.move(to: .zero, duration: 0.05))
        let shake = SKAction.sequence(steps)
        for layer in [courtLayer, playersLayer, ballLayer] {
            layer.removeAction(forKey: "shake")
            layer.run(shake, withKey: "shake")
        }
    }

    private func flashScreen() {
        let flash = SKShapeNode(rect: CGRect(origin: .zero, size: size))
        flash.fillColor = SKColor(red: 1, green: 0.62, blue: 0.18, alpha: 1)
        flash.strokeColor = .clear
        flash.alpha = 0
        flash.zPosition = 240
        fxLayer.addChild(flash)
        flash.run(SKAction.sequence([
            SKAction.fadeAlpha(to: 0.4, duration: 0.08),
            SKAction.fadeOut(withDuration: 0.4),
            SKAction.removeFromParent(),
        ]))
    }

    private func rattleRim() {
        guard let rimNode else { return }
        rimNode.removeAction(forKey: "rattle")
        rimNode.run(SKAction.sequence([
            SKAction.moveBy(x: 0, y: -3, duration: 0.05),
            SKAction.moveBy(x: 0, y: 4.5, duration: 0.06),
            SKAction.moveBy(x: 0, y: -1.5, duration: 0.05),
        ]), withKey: "rattle")
    }

    private func updateShotClock(dt: TimeInterval) {
        guard playState == .homeLive else { return }
        shotClockRemaining -= dt
        if shotClockRemaining <= 0 {
            showCallout("SHOT CLOCK!", color: .red)
            HapticManager.notification(.error)
            cancelCharge()
            givePossession(to: .away)
        }
    }

    private func resolveExpiredFlight(_ now: TimeInterval) {
        guard playState == .homeShot || playState == .awayShot else { return }
        guard now > shotDeadline, pendingPossession == nil, let ball, !ball.isHeld else { return }
        scheduleGivePossession(to: ball.shotTeam == .home ? .away : .home, after: 0.1)
    }

    private func updateDepthSorting() {
        // Web-game depth: nearer (lower on screen) players draw bigger and in front.
        let bandRange = max(1, courtBandMaxY - courtBandMinY)
        for player in players.values {
            let nearness = (courtBandMaxY - player.position.y) / bandRange
            player.zPosition = 40 + nearness * 20
            player.setScale(0.85 + 0.22 * nearness)
        }
    }

    // MARK: - Touch handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            if phase == .ended {
                _ = resultCard?.handleTouch(touch)
                continue
            }
            guard phase == .playing else { continue }

            let p = touch.location(in: self)
            if shootTouch == nil,
               playState == .homeLive,
               let btn = shootButton,
               hypot(p.x - btn.position.x, p.y - btn.position.y) <= 86 {
                shootTouch = touch
                chargeActive = true
                charge = 0
                shootButton?.setCharge(0)
                stormSky?.setCharge(0)
                HapticManager.impact(.light)
            } else if shootTouch == nil,
                      playState == .awayLive,
                      let btn = shootButton,
                      hypot(p.x - btn.position.x, p.y - btn.position.y) <= 86 {
                shootTouch = touch
                tryHumanSteal()
            } else if joystickTouch == nil, p.y < size.height - 140 {
                joystickTouch = touch
                joystick?.begin(at: p)
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let stickTouch = joystickTouch, touches.contains(stickTouch) else { return }
        joystick?.move(to: stickTouch.location(in: self))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        handleTouchesFinished(touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        handleTouchesFinished(touches)
    }

    private func handleTouchesFinished(_ touches: Set<UITouch>) {
        for touch in touches {
            if touch == shootTouch {
                shootTouch = nil
                if chargeActive {
                    let released = charge
                    cancelCharge()
                    releaseShot(charge: released)
                }
            }
            if touch == joystickTouch {
                joystickTouch = nil
                joystick?.end()
            }
        }
    }

    // MARK: - Shooting

    private func releaseShot(charge: CGFloat) {
        guard phase == .playing,
              playState == .homeLive,
              possession == .home,
              let id = activeHumanID,
              let player = players[id],
              let ball, ball.isHeld else { return }

        registerBeatTiming(nowTime)

        let dist = abs(rimX - player.position.x)
        let beyondArc = player.position.x < threePointX
        var contested = false
        for awayID in awayIDs {
            if let defender = players[awayID],
               hypot(defender.position.x - player.position.x, defender.position.y - player.position.y) < 62 {
                contested = true
                break
            }
        }
        let error = shotError(charge: charge, dist: dist, beyondArc: beyondArc,
                              contested: contested, hero: player.heroID.character)

        if contested {
            showCallout("CONTESTED!", color: SKColor(red: 1, green: 0.35, blue: 0.3, alpha: 1))
        }
        if charge >= perfectLow && charge <= perfectHigh {
            showCallout(player.heroID.character.quip, color: SKColor(red: 1, green: 0.84, blue: 0, alpha: 1))
        }

        playState = .homeShot
        player.playAnimationOnce(.shoot)
        pendingLaunch = PendingLaunch(
            at: nowTime + shootWindupDelay,
            team: .home,
            errorOffset: CGFloat.random(in: -error...error)
        )
        HapticManager.impact(.medium)
    }

    private func tryHumanSteal() {
        guard nowTime > humanStealCooldownUntil,
              let handlerID = cpuHandlerID, let handler = players[handlerID],
              let humanID = activeHumanID, let human = players[humanID] else { return }

        let dist = hypot(handler.position.x - human.position.x, handler.position.y - human.position.y)
        humanStealCooldownUntil = nowTime + 3.0
        guard dist < 52 else {
            showCallout("GET CLOSER!", color: SKColor.white.withAlphaComponent(0.55))
            return
        }

        let chance = (0.15 + human.heroID.character.stealBonus * 2.0) / (1.0 + difficulty.cpuStealRate * 0.5)
        if CGFloat.random(in: 0...1) < chance {
            showCallout("STEAL!", color: SKColor(red: 0.4, green: 0.95, blue: 0.5, alpha: 1))
            HapticManager.notification(.success)
            givePossession(to: .home)
        } else {
            showCallout("NO GOOD", color: SKColor.white.withAlphaComponent(0.5))
            HapticManager.impact(.rigid)
        }
    }

    private func shotError(charge: CGFloat, dist: CGFloat, beyondArc: Bool,
                           contested: Bool, hero: HalfCourtHero) -> CGFloat {
        let c = min(charge, 1.2)
        var accuracy: CGFloat
        if c >= perfectLow && c <= perfectHigh {
            accuracy = difficulty.perfectAccuracy
        } else if c >= greenLow && c <= greenHigh {
            accuracy = difficulty.greenAccuracy
        } else {
            accuracy = difficulty.lateAccuracy
        }
        accuracy -= dist * 0.00025
        if contested { accuracy -= 0.12 }
        if beyondArc { accuracy += hero.threeBonus }
        if !beyondArc { accuracy += hero.closeBonus }
        if isPowered { accuracy += 0.15 }
        accuracy = max(0.05, min(1.0, accuracy))
        return CGFloat.random(in: 0...1) < accuracy
            ? CGFloat.random(in: 2...5)
            : CGFloat.random(in: 20...55)
    }

    private func registerBeatTiming(_ now: TimeInterval) {
        let delta = nearestBeatDelta(now)
        if delta <= onBeatWindow {
            onBeatStreak += 1
            if onBeatStreak >= 3 {
                onBeatStreak = 0
                activatePowerUp(now)
            } else {
                showCallout("ON BEAT ×\(onBeatStreak)", color: SKColor(red: 1, green: 0.84, blue: 0, alpha: 1))
                HapticManager.impact(.rigid)
            }
        } else {
            if onBeatStreak > 0 {
                showCallout("OFF BEAT", color: SKColor.white.withAlphaComponent(0.55))
            }
            onBeatStreak = 0
        }
        streakPips?.set(count: onBeatStreak, powered: isPowered)
    }

    private func activatePowerUp(_ now: TimeInterval) {
        poweredUntil = now + powerUpDuration
        isPowered = true
        if let id = activeHumanID {
            players[id]?.setOnFire(true)
        }
        streakPips?.set(count: 3, powered: true)
        showCallout("🔥 ON FIRE!", color: SKColor(red: 1, green: 0.55, blue: 0.1, alpha: 1), big: true)
        flashScreen()
        shakeWorld(9)
        HapticManager.notification(.success)
        HapticManager.impact(.heavy)
    }

    private func performLaunch(_ launch: PendingLaunch) {
        guard phase == .playing, let ball, ball.isHeld else { return }
        let holderID = launch.team == .home ? activeHumanID : cpuHandlerID
        guard let holderID, let holder = players[holderID] else { return }

        let local = holder.shotReleasePoint()
        let s = abs(holder.xScale)
        let start = CGPoint(x: holder.position.x + local.x * s, y: holder.position.y + local.y * s)
        let dist = abs(rimX - start.x)
        let points = holder.position.x < threePointX ? 3 : 2
        let flightTime = 0.82 + dist / 700
        let target = CGPoint(x: rimX + launch.errorOffset, y: rimY)
        let velocity = launchVelocity(from: start, to: target, flightTime: flightTime)

        ball.position = start
        ball.launch(velocity: velocity, team: launch.team, points: points)
        let flaming = isPowered && launch.team == .home
        ball.setOnFire(flaming)
        ballTrailActive = flaming
        ball.zPosition = 70
        shotDeadline = nowTime + TimeInterval(flightTime) + 3.2
        if launch.team == .away {
            cpuState = .idle
        }
    }

    /// SpriteKit's physics uses 150 points per meter; gravity is in m/s².
    private var gravityPointsPerSec2: CGFloat {
        abs(physicsWorld.gravity.dy) * 150
    }

    private func launchVelocity(from start: CGPoint, to target: CGPoint, flightTime: CGFloat) -> CGVector {
        let g = gravityPointsPerSec2
        let vx = (target.x - start.x) / flightTime
        let vy = (target.y - start.y) / flightTime + 0.5 * g * flightTime
        return CGVector(dx: vx, dy: vy)
    }

    // MARK: - SKPhysicsContactDelegate

    func didBegin(_ contact: SKPhysicsContact) {
        let collision = contact.bodyA.categoryBitMask | contact.bodyB.categoryBitMask
        if collision == (HalfCourtPhysicsCategory.ball | HalfCourtPhysicsCategory.net) {
            handleScore()
        } else if collision == (HalfCourtPhysicsCategory.ball | HalfCourtPhysicsCategory.court) {
            handleFloorContact()
        }
    }

    private func handleScore() {
        guard let ball, !ball.isHeld, !ball.scoredThisFlight, !ball.missResolved else { return }
        guard (ball.physicsBody?.velocity.dy ?? 0) < 0 else { return }
        ball.scoredThisFlight = true

        var points = ball.shotPoints
        rattleRim()
        if ball.shotTeam == .home {
            if isPowered { points += 1 }
            homeScore += points
            showCallout(isPowered ? "+\(points) 🔥" : "+\(points)",
                        color: SKColor(red: 1.0, green: 0.08, blue: 0.58, alpha: 1), big: true)
            HapticManager.notification(.success)
            shakeWorld(isPowered ? 12 : 6)
            for id in homeIDs {
                players[id]?.playAnimationOnce(.celebrate)
            }
        } else {
            awayScore += points
            showCallout("CPU +\(points)", color: SKColor(red: 1.0, green: 0.42, blue: 0.21, alpha: 1))
            HapticManager.impact(.medium)
            if let id = cpuHandlerID {
                players[id]?.playAnimationOnce(.celebrate)
            }
        }

        if homeScore >= winScore || awayScore >= winScore {
            if homeScore >= winScore { homeSeriesWins += 1 } else { awaySeriesWins += 1 }
            pendingResolveAt = nowTime + 1.0
        } else {
            scheduleGivePossession(to: ball.shotTeam == .home ? .away : .home, after: 1.0)
        }
    }

    private func handleFloorContact() {
        guard let ball, !ball.isHeld, !ball.scoredThisFlight, !ball.missResolved else { return }
        guard playState == .homeShot || playState == .awayShot else { return }
        ball.missResolved = true
        if ball.shotTeam == .home {
            showCallout(["MISS", "OFF THE RIM", "NO GOOD"].randomElement() ?? "MISS",
                        color: SKColor.white.withAlphaComponent(0.6))
            HapticManager.impact(.medium)
        } else {
            showCallout(["BRICKED!", "CPU MISSES", "BLOCKED OUT"].randomElement() ?? "BRICKED!",
                        color: SKColor(red: 0.4, green: 0.95, blue: 0.5, alpha: 0.85))
        }
        scheduleGivePossession(to: ball.shotTeam == .home ? .away : .home, after: 0.6)
    }

    // MARK: - Game end

    private func resolveGame() {
        let isSeriesOver = homeSeriesWins >= seriesWinTarget || awaySeriesWins >= seriesWinTarget
        if isSeriesOver {
            if homeSeriesWins >= seriesWinTarget {
                HapticManager.notification(.success)
                HapticManager.impact(.heavy)
                flashScreen()
            } else {
                HapticManager.notification(.error)
            }
        }
        let card = HalfCourtResultCardNode(
            homeScore: homeScore,
            awayScore: awayScore,
            homeWins: homeSeriesWins,
            awayWins: awaySeriesWins,
            isSeriesOver: isSeriesOver,
            onAction: { [weak self] in
                guard let self else { return }
                if isSeriesOver {
                    self.onDismiss?()
                } else {
                    self.homeScore = 0
                    self.awayScore = 0
                    self.resetMatch()
                    self.phase = .playing
                }
            }
        )
        card.position = CGPoint(x: size.width / 2, y: size.height / 2)
        card.setScale(min(1, size.width / 440))
        card.alpha = 0
        uiLayer.addChild(card)
        resultCard = card
        phase = .ended
        card.run(SKAction.group([
            SKAction.fadeIn(withDuration: 0.28),
            SKAction.sequence([
                SKAction.scale(by: 1.08, duration: 0.14),
                SKAction.scale(to: min(1, size.width / 440), duration: 0.14),
            ]),
        ]))
    }

    // MARK: - Callouts

    private func showCallout(_ text: String, color: SKColor, big: Bool = false) {
        calloutNode?.removeFromParent()

        let label = SKLabelNode(text: text)
        label.fontName = "AvenirNext-Heavy"
        label.fontSize = big ? 30 : 19
        label.fontColor = color
        label.position = CGPoint(x: size.width / 2, y: size.height * 0.58)
        label.zPosition = 200
        label.setScale(0.6)
        label.alpha = 0
        fxLayer.addChild(label)
        calloutNode = label

        let pop = SKAction.group([
            SKAction.fadeIn(withDuration: 0.1),
            SKAction.sequence([
                SKAction.scale(to: 1.08, duration: 0.12),
                SKAction.scale(to: 1.0, duration: 0.08),
            ]),
        ])
        let out = SKAction.sequence([
            SKAction.wait(forDuration: big ? 1.0 : 0.7),
            SKAction.group([
                SKAction.fadeOut(withDuration: 0.25),
                SKAction.moveBy(x: 0, y: 24, duration: 0.25),
            ]),
            SKAction.removeFromParent(),
        ])
        label.run(SKAction.sequence([pop, out]))
    }
}

// MARK: - Shoot button with charge meter + beat ring

@MainActor
final class ShootButtonNode: SKNode {
    private let radius: CGFloat = 56
    private let base = SKShapeNode(circleOfRadius: 56)
    private let beatRing = SKShapeNode(circleOfRadius: 56)
    private let greenArc = SKShapeNode()
    private let perfectArc = SKShapeNode()
    private let meterArc = SKShapeNode()
    private let label = SKLabelNode(text: "SHOOT")
    private let ballIcon = SKShapeNode(circleOfRadius: 13)

    private var greenLow: CGFloat
    private var greenHigh: CGFloat
    private var perfectLow: CGFloat
    private var perfectHigh: CGFloat

    // Meter sweeps 240° clockwise starting at the lower-left
    private let startAngle: CGFloat = .pi * 7 / 6      // 210°
    private let sweep: CGFloat = .pi * 4 / 3           // 240°

    init(greenLow: CGFloat, greenHigh: CGFloat, perfectLow: CGFloat, perfectHigh: CGFloat) {
        self.greenLow = greenLow
        self.greenHigh = greenHigh
        self.perfectLow = perfectLow
        self.perfectHigh = perfectHigh
        super.init()
        setup()
    }

    required init?(coder aDecoder: NSCoder) { fatalError() }

    private func angle(for charge: CGFloat) -> CGFloat {
        startAngle - sweep * min(charge, 1)
    }

    private func arcPath(from a: CGFloat, to b: CGFloat, radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.addArc(center: .zero, radius: radius, startAngle: a, endAngle: b, clockwise: true)
        return path
    }

    private func setup() {
        let pink = SKColor(red: 1.0, green: 0.08, blue: 0.58, alpha: 1)

        base.fillColor = pink.withAlphaComponent(0.2)
        base.strokeColor = pink.withAlphaComponent(0.85)
        base.lineWidth = 3
        addChild(base)

        beatRing.fillColor = .clear
        beatRing.strokeColor = SKColor(red: 1, green: 0.84, blue: 0, alpha: 0.9)
        beatRing.lineWidth = 3
        beatRing.alpha = 0
        addChild(beatRing)

        greenArc.path = arcPath(from: angle(for: greenLow), to: angle(for: greenHigh), radius: 47)
        greenArc.strokeColor = SKColor(red: 0.2, green: 0.83, blue: 0.2, alpha: 0.45)
        greenArc.lineWidth = 6
        greenArc.lineCap = .round
        greenArc.isHidden = true
        addChild(greenArc)

        perfectArc.path = arcPath(from: angle(for: perfectLow), to: angle(for: perfectHigh), radius: 47)
        perfectArc.strokeColor = SKColor(red: 1, green: 0.84, blue: 0, alpha: 0.7)
        perfectArc.lineWidth = 6
        perfectArc.lineCap = .round
        perfectArc.isHidden = true
        addChild(perfectArc)

        meterArc.strokeColor = .white
        meterArc.lineWidth = 6
        meterArc.lineCap = .round
        meterArc.isHidden = true
        addChild(meterArc)

        ballIcon.fillColor = SKColor(red: 0.85, green: 0.42, blue: 0.11, alpha: 0.9)
        ballIcon.strokeColor = SKColor(red: 0.6, green: 0.25, blue: 0.05, alpha: 0.8)
        ballIcon.lineWidth = 1.5
        ballIcon.position = CGPoint(x: 0, y: 13)
        addChild(ballIcon)

        label.fontName = "AvenirNext-Bold"
        label.fontSize = 13
        label.fontColor = pink.withAlphaComponent(0.9)
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: 0, y: -21)
        addChild(label)

        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.05, duration: 0.7),
            SKAction.scale(to: 0.97, duration: 0.7),
        ])
        base.run(SKAction.repeatForever(pulse))
    }

    func reconfigureArcs(greenLow: CGFloat, greenHigh: CGFloat, perfectLow: CGFloat, perfectHigh: CGFloat) {
        self.greenLow = greenLow
        self.greenHigh = greenHigh
        self.perfectLow = perfectLow
        self.perfectHigh = perfectHigh
        greenArc.path = arcPath(from: angle(for: greenLow), to: angle(for: greenHigh), radius: 47)
        perfectArc.path = arcPath(from: angle(for: perfectLow), to: angle(for: perfectHigh), radius: 47)
    }

    func setEnabled(_ enabled: Bool) {
        alpha = enabled ? 1 : 0.3
    }

    func setMode(stealing: Bool) {
        label.text = stealing ? "STEAL" : "SHOOT"
    }

    /// nil hides the meter; 0...1+ draws the charge sweep.
    func setCharge(_ charge: CGFloat?) {
        guard let charge else {
            meterArc.isHidden = true
            greenArc.isHidden = true
            perfectArc.isHidden = true
            return
        }
        greenArc.isHidden = false
        perfectArc.isHidden = false
        meterArc.isHidden = charge <= 0.01
        meterArc.path = arcPath(from: startAngle, to: angle(for: charge), radius: 47)

        if charge >= perfectLow && charge <= perfectHigh {
            meterArc.strokeColor = SKColor(red: 1, green: 0.84, blue: 0, alpha: 1)
        } else if charge >= greenLow && charge <= greenHigh {
            meterArc.strokeColor = SKColor(red: 0.2, green: 0.83, blue: 0.2, alpha: 1)
        } else if charge > greenHigh {
            meterArc.strokeColor = SKColor(red: 1, green: 0.25, blue: 0.2, alpha: 1)
        } else {
            meterArc.strokeColor = .white
        }
    }

    func beatPulse() {
        beatRing.removeAllActions()
        beatRing.setScale(1)
        beatRing.alpha = 0.9
        beatRing.run(SKAction.group([
            SKAction.scale(to: 1.45, duration: 0.3),
            SKAction.fadeOut(withDuration: 0.3),
        ]))
    }
}

// MARK: - Floating joystick

@MainActor
final class JoystickNode: SKNode {
    private let baseRadius: CGFloat = 46
    private let base = SKShapeNode(circleOfRadius: 46)
    private let knob = SKShapeNode(circleOfRadius: 20)

    private(set) var vector = CGVector.zero

    override init() {
        super.init()
        base.fillColor = SKColor.black.withAlphaComponent(0.22)
        base.strokeColor = SKColor.white.withAlphaComponent(0.3)
        base.lineWidth = 2
        addChild(base)

        knob.fillColor = SKColor.white.withAlphaComponent(0.75)
        knob.strokeColor = .clear
        addChild(knob)

        isHidden = true
    }

    required init?(coder aDecoder: NSCoder) { fatalError() }

    func begin(at point: CGPoint) {
        position = point
        knob.position = .zero
        vector = .zero
        isHidden = false
    }

    func move(to scenePoint: CGPoint) {
        var dx = scenePoint.x - position.x
        var dy = scenePoint.y - position.y
        let dist = hypot(dx, dy)
        if dist > baseRadius {
            dx = dx / dist * baseRadius
            dy = dy / dist * baseRadius
        }
        knob.position = CGPoint(x: dx, y: dy)
        vector = CGVector(dx: dx / baseRadius, dy: dy / baseRadius)
    }

    func end() {
        isHidden = true
        knob.position = .zero
        vector = .zero
    }
}

// MARK: - On-beat streak pips

@MainActor
final class StreakPipsNode: SKNode {
    private var pips: [SKShapeNode] = []

    override init() {
        super.init()
        for i in 0..<3 {
            let pip = SKShapeNode(circleOfRadius: 6)
            pip.position = CGPoint(x: CGFloat(i - 1) * 22, y: 0)
            pip.fillColor = .clear
            pip.strokeColor = SKColor(red: 1, green: 0.84, blue: 0, alpha: 0.5)
            pip.lineWidth = 1.5
            addChild(pip)
            pips.append(pip)
        }
    }

    required init?(coder aDecoder: NSCoder) { fatalError() }

    func set(count: Int, powered: Bool) {
        for (i, pip) in pips.enumerated() {
            pip.removeAllActions()
            pip.setScale(1)
            if powered {
                pip.fillColor = SKColor(red: 1, green: 0.45, blue: 0.08, alpha: 1)
                pip.strokeColor = SKColor(red: 1, green: 0.7, blue: 0.15, alpha: 1)
                let pulse = SKAction.sequence([
                    SKAction.scale(to: 1.3, duration: 0.25),
                    SKAction.scale(to: 1.0, duration: 0.25),
                ])
                pip.run(SKAction.repeatForever(pulse))
            } else if i < count {
                pip.fillColor = SKColor(red: 1, green: 0.84, blue: 0, alpha: 0.95)
                pip.strokeColor = SKColor(red: 1, green: 0.84, blue: 0, alpha: 1)
                pip.run(SKAction.sequence([
                    SKAction.scale(to: 1.4, duration: 0.1),
                    SKAction.scale(to: 1.0, duration: 0.12),
                ]))
            } else {
                pip.fillColor = .clear
                pip.strokeColor = SKColor(red: 1, green: 0.84, blue: 0, alpha: 0.5)
            }
        }
    }
}
