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
    private let onBeatWindow: TimeInterval = 0.175
    private let powerUpDuration: TimeInterval = 12
    private var shotClockSeconds: TimeInterval = 10
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

    /// Safe-area insets pushed in from SwiftUI (the scene runs under `.ignoresSafeArea()`,
    /// so it cannot read them itself). Re-lays out on change so landscape controls clear
    /// the notch / home indicator.
    var safeInsets: UIEdgeInsets = .zero {
        didSet { if view != nil { layoutScene() } }
    }

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
    private var streakPips: StreakPipsNode?
    private var tapMeterNode: TapShotMeterNode?
    private var calloutNode: SKNode?
    private var stealHintNode: SKNode?
    private var rimNode: SKShapeNode?
    private var rimHaloNode: SKShapeNode?
    private var posterNode: SKNode?
    private var nbaJerseysEnabled: Bool = false
    private var ballTrailActive = false
    private var trailFrameCounter = 0

    var onDismiss: (() -> Void)?

    // MARK: - Match state
    @Published private(set) var phase: HalfCourtPhase = .title
    @Published private(set) var difficulty: HalfCourtDifficulty = .normal
    /// Player-selected control scheme (persisted). Seeded from UserDefaults so it
    /// survives scene recreation; the property-initializer does NOT fire `didSet`.
    @Published var controlStyle: HalfCourtControlStyle = HalfCourtControlStyle.loadPersisted() {
        didSet { UserDefaults.standard.set(controlStyle.rawValue, forKey: HalfCourtControlStyle.storageKey) }
    }
    @Published var homeScore = 0
    @Published var awayScore = 0
    @Published var homeSeriesWins = 0
    @Published var awaySeriesWins = 0

    private enum PlayState {
        case homeLive       // human has the ball
        case homeShot       // human shot in windup or flight
        case awayLive       // CPU has the ball
        case awayShot       // CPU shot in windup or flight
        case homeFreethrow  // human shooting free throws after a shooting foul
    }

    private enum CPUState {
        case idle
        case bringUp(CGPoint)
        case dribbling(TimeInterval)
        case shooting
    }

    /// What the on-screen buttons should represent right now, derived from
    /// `phase` + `playState` + `possession` + `controlStyle`.
    private enum ControlContext {
        case offenseBallHoopLand, offenseBallJumpBall, freeThrow, defenseLive, defenseShot, none
    }
    private var controlContext: ControlContext {
        guard phase == .playing else { return .none }
        switch playState {
        case .homeLive where possession == .home:
            return controlStyle == .jumpBall ? .offenseBallJumpBall : .offenseBallHoopLand
        case .homeFreethrow: return .freeThrow
        case .awayLive:      return .defenseLive
        case .awayShot:      return .defenseShot
        default:             return .none   // .homeShot, or ball not with home
        }
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
    private var lastShotClockInt: Int = 100
    private var lastUpdate: TimeInterval?
    private var nowTime: TimeInterval = 0

    // Touch routing — left thumb moves player, right thumb shoots/blocks/steals/passes
    private var joystickNode: JoystickNode?
    private var leftTouch: UITouch?
    private var leftTouchPrev: CGPoint = .zero
    private var leftTouchStartPos: CGPoint = .zero
    private var leftTouchStartTime: TimeInterval = 0
    private var leftImpulse: CGVector = .zero
    private var lastLeftInputTime: TimeInterval = 0
    private var tapMeterFill: CGFloat = 0
    private var chargeRate: CGFloat = 0.95       // fills meter per second while holding
    private let meterDecayRate: CGFloat = 0.18
    private var isChargingShot = false           // SHOOT button held (drives the charge meter)

    // On-screen control buttons (replace the retired gesture action-zone)
    private var buttonA: ControlButtonNode?      // SHOOT / JUMP / BLOCK (primary, right)
    private var buttonB: ControlButtonNode?      // PASS / STEAL (secondary, left)
    private var shootButtonTouch: UITouch?       // owns the hold-to-charge SHOOT press
    private var contestResolved = false          // one block/foul per .awayShot (double-fire guard)
    private var jumpBallShotCount = 0            // deterministic JumpBall spread index
    private var freethrowsRemaining = 0
    private var isFreethrowInFlight = false
    private var cpuBlockFill: CGFloat = 0
    private var blockWindowOpened = false
    // Green zone (0.52–0.76) opens at 0.52s, closes at 0.76s — ball launches at 0.29s
    // so the block window sits squarely during the ball's flight, not after it scores.
    private let cpuBlockFillRate: CGFloat = 1.0

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

        if tapMeterNode == nil {
            let meterWidth = min(size.width, size.height) * 0.34
            let meter = TapShotMeterNode(barWidth: meterWidth,
                                         greenLow: greenLow, greenHigh: greenHigh,
                                         perfectLow: perfectLow, perfectHigh: perfectHigh)
            meter.zPosition = 115
            meter.isHidden = true
            uiLayer.addChild(meter)
            tapMeterNode = meter
        }

        if buttonA == nil {
            let a = ControlButtonNode(radius: 42)
            a.isHidden = true
            uiLayer.addChild(a)
            buttonA = a
        }
        if buttonB == nil {
            let b = ControlButtonNode(radius: 34)
            b.isHidden = true
            uiLayer.addChild(b)
            buttonB = b
        }

        if streakPips == nil {
            let pips = StreakPipsNode()
            pips.zPosition = 110
            pips.isHidden = true
            uiLayer.addChild(pips)
            streakPips = pips
        }

        if joystickNode == nil {
            let joy = JoystickNode()
            joy.zPosition = 120
            uiLayer.addChild(joy)
            joystickNode = joy
        }

        physicsWorld.gravity = CGVector(dx: 0, dy: -9.0)
        physicsWorld.contactDelegate = self
        nbaJerseysEnabled = UserDefaults.standard.bool(forKey: "hch_nba_jerseys_mod")

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

        // Safe-area-aware bounds so the hoop + right-thumb buttons clear the
        // landscape notch / home indicator. Prefer SwiftUI-pushed insets; fall back
        // to the UIKit window insets (the SKView itself ignores the safe area).
        let ins = safeInsets == .zero ? (view?.window?.safeAreaInsets ?? .zero) : safeInsets
        let safeL = max(ins.left, 0)
        let safeR = w - max(ins.right, 0)
        let safeB = max(ins.bottom, 8)
        let safeW = safeR - safeL

        floorY = max(70, h * 0.12)
        courtBandMinY = max(44, h * 0.055)
        courtBandMaxY = h * 0.30
        rimX = safeR - 58
        rimY = h * 0.62
        threePointX = rimX - safeW * 0.56
        playerMinX = safeL + 44
        playerMaxX = rimX - 56
        playerSpriteSize = min(170, max(118, h * 0.17))

        buildCourt()
        hud?.layout(size: size, safeInsets: safeInsets)

        // Compact translucent controls tucked into the bottom-right corner so they clear
        // the court/hoop. Charge & block-timing feedback is a ring around SHOOT (buttonA),
        // so the old wide meter bar is retired (kept hidden; it still drives tapMeterFill).
        tapMeterNode?.isHidden = true
        resultCard?.position = CGPoint(x: (safeL + safeR) / 2, y: h / 2)

        buttonA?.position = CGPoint(x: safeR - 52,  y: safeB + 66)   // SHOOT / JUMP / BLOCK
        buttonB?.position = CGPoint(x: safeR - 150, y: safeB + 54)   // PASS / STEAL
        buttonA?.configureRing(greenLow: greenLow, greenHigh: greenHigh,
                               perfectLow: perfectLow, perfectHigh: perfectHigh)
        streakPips?.position = CGPoint(x: safeR - 52, y: safeB + 126)

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

        // Beat halo — pulses around the rim on every beat of the song (F1)
        let halo = SKShapeNode(circleOfRadius: 30)
        halo.strokeColor = SKColor(red: 1, green: 0.84, blue: 0, alpha: 1)
        halo.lineWidth = 2
        halo.fillColor = .clear
        halo.alpha = 0
        halo.position = CGPoint(x: rimX, y: rimY)
        courtLayer.addChild(halo)
        rimHaloNode = halo

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

        // Knicks poster easter egg — small decoration on the wall above the court band
        let poster = SKNode()
        poster.position = CGPoint(x: w * 0.15, y: size.height * 0.42)
        poster.zPosition = -8

        let posterBg = SKShapeNode(rectOf: CGSize(width: 32, height: 44), cornerRadius: 2)
        posterBg.fillColor = SKColor(red: 0.0, green: 0.42, blue: 0.71, alpha: 0.88)
        posterBg.strokeColor = nbaJerseysEnabled
            ? SKColor(red: 1.0, green: 0.85, blue: 0.0, alpha: 1.0)
            : SKColor(red: 1.0, green: 0.55, blue: 0.0, alpha: 0.85)
        posterBg.lineWidth = nbaJerseysEnabled ? 3.5 : 2.0
        poster.addChild(posterBg)

        let nyLabel = SKLabelNode(text: "NY")
        nyLabel.fontName = "AvenirNext-Heavy"
        nyLabel.fontSize = 14
        nyLabel.fontColor = .white
        nyLabel.verticalAlignmentMode = .center
        nyLabel.position = CGPoint(x: 0, y: 5)
        poster.addChild(nyLabel)

        let knickLabel = SKLabelNode(text: "KNICKS")
        knickLabel.fontName = "AvenirNext-Bold"
        knickLabel.fontSize = 5.5
        knickLabel.fontColor = SKColor(red: 1.0, green: 0.55, blue: 0.0, alpha: 1)
        knickLabel.verticalAlignmentMode = .center
        knickLabel.position = CGPoint(x: 0, y: -9)
        poster.addChild(knickLabel)

        courtLayer.addChild(poster)
        posterNode = poster
    }

    // MARK: - Match management

    func startSeries() {
        homeSeriesWins = 0
        awaySeriesWins = 0
        beatAnchor = nil   // reset so next series re-aligns beat clock to the restarted track
        phase = .characterSelect
    }

    // Called by the view after playTrack() confirms 204, so the anchor latches
    // when audio has actually (re)started rather than when the API call was fired.
    func realignBeatAnchor() {
        beatAnchor = nil
    }

    func startGame(playerID: HalfCourtHeroID, teammateID: HalfCourtHeroID, difficulty: HalfCourtDifficulty = .normal) {
        self.difficulty = difficulty
        let d = difficulty
        greenLow = d.greenWindow.low / 100
        greenHigh = d.greenWindow.high / 100
        let mid = (greenLow + greenHigh) / 2
        perfectLow = mid - 0.05
        perfectHigh = mid + 0.05
        cpuShotMult = d.cpuShotMultiplier
        shotClockSeconds = d.shotClockSeconds
        chargeRate = d.chargeRate

        tapMeterNode?.reconfigure(greenLow: greenLow, greenHigh: greenHigh,
                                   perfectLow: perfectLow, perfectHigh: perfectHigh)
        buttonA?.configureRing(greenLow: greenLow, greenHigh: greenHigh,
                               perfectLow: perfectLow, perfectHigh: perfectHigh)

        homeIDs = [playerID, teammateID]
        awayIDs = HalfCourtHeroID.allCases.filter { !homeIDs.contains($0) }
        activeHumanID = playerID

        homeScore = 0
        awayScore = 0
        // Don't reset beatAnchor — audio plays continuously through the series,
        // so the visual beat clock must also carry over for games 2–5 to stay in sync.
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
        poweredUntil = 0
        isPowered = false
        onBeatStreak = 0
        freethrowsRemaining = 0
        isFreethrowInFlight = false
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
        let node = PlayerNode(heroID: id, team: team, spriteSize: playerSpriteSize, nbaJerseys: nbaJerseysEnabled)
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
        isFreethrowInFlight = false
        ball?.hold()
        ball?.setOnFire(false)
        shotClockRemaining = shotClockSeconds
        lastShotClockInt = 100
        resetTapMeter()
        hideStealHint()

        if team == .home {
            playState = .homeLive
            cpuState = .idle
        } else {
            playState = .awayLive
            cpuHandlerID = awayIDs.randomElement()
            cpuState = .bringUp(pickCPUSpot())
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
        lastUpdate = currentTime

        // When the scene was paused (zoom freeze), SpriteKit's currentTime kept
        // advancing with wall-clock time. Compensate by shifting beatAnchor forward
        // so the visual beat clock stays aligned with the resumed audio.
        if rawDt > 0.5, let anchor = beatAnchor {
            beatAnchor = anchor + rawDt
        }

        let dt = CGFloat(min(max(rawDt, 0), 1.0 / 20.0))

        guard phase == .playing else {
            hud?.isHidden = true
            tapMeterNode?.isHidden = true
            streakPips?.isHidden = true
            buttonA?.isHidden = true
            buttonB?.isHidden = true
            return
        }
        hud?.isHidden = false
        tapMeterNode?.isHidden = true   // retired in favour of the ring around the SHOOT button
        streakPips?.isHidden = false
        refreshControlButtons()

        updateBeat(currentTime)
        updatePowerState(currentTime)
        firePendingTransitions(currentTime)
        updateTapMeter(dt: dt, now: currentTime)
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

        hud?.update(
            homeScore: homeScore,
            awayScore: awayScore,
            homeWins: homeSeriesWins,
            awayWins: awaySeriesWins,
            shotClock: playState == .homeLive ? Int(ceil(shotClockRemaining)) : 0,
            powered: isPowered,
            powerRemaining: max(0, Int(ceil(poweredUntil - currentTime))),
            heroName: activeHumanID?.character.name ?? "YOU"
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
            tapMeterNode?.beatPulse()
            rimBeatHalo()
            if playState == .homeLive || playState == .homeFreethrow {
                buttonA?.beatPulse()   // only in SHOOT contexts — never during BLOCK timing
            }
            if onBeatStreak > 0 { streakPips?.beatFlash() }
            if playState == .homeLive {
                HapticManager.selection()
            }
        }
    }

    private func rimBeatHalo() {
        guard let rimHaloNode else { return }
        rimHaloNode.removeAllActions()
        rimHaloNode.setScale(1.0)
        rimHaloNode.alpha = 0.5
        rimHaloNode.run(.group([.scale(to: 1.18, duration: 0.30), .fadeOut(withDuration: 0.30)]))
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
            HapticManager.impact(.rigid)
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

    private func updateTapMeter(dt: CGFloat, now: TimeInterval) {
        switch playState {
        case .awayShot:
            cpuBlockFill = min(cpuBlockFill + cpuBlockFillRate * dt, 1.1)
            if !blockWindowOpened && cpuBlockFill >= greenLow {
                blockWindowOpened = true
                showCallout("BLOCK NOW!", color: SKColor(red: 1.0, green: 0.75, blue: 0.2, alpha: 1))
                HapticManager.impact(.rigid)
            }
            tapMeterNode?.setFill(cpuBlockFill, mode: .block)
        case .homeLive where possession == .home:
            if isChargingShot {
                tapMeterFill = min(tapMeterFill + chargeRate * dt, 1.2)
            } else {
                tapMeterFill = max(0, tapMeterFill - meterDecayRate * dt)
            }
            tapMeterNode?.setFill(tapMeterFill, mode: .shoot)
        case .homeFreethrow:
            if isChargingShot {
                tapMeterFill = min(tapMeterFill + chargeRate * dt, 1.2)
            } else {
                tapMeterFill = max(0, tapMeterFill - meterDecayRate * dt)
            }
            tapMeterNode?.setFill(tapMeterFill, mode: .shoot)
        default:
            tapMeterFill = 0
            tapMeterNode?.setFill(0, mode: .shoot)
        }
    }

    private func resetTapMeter() {
        tapMeterFill = 0
        cpuBlockFill = 0
        blockWindowOpened = false
        isChargingShot = false
        contestResolved = false
        tapMeterNode?.setFill(0, mode: .shoot)
    }

    private func updateHuman(_ dt: CGFloat) {
        guard let id = activeHumanID, let player = players[id] else { return }
        var moving = false
        let canMove = playState == .homeLive || playState == .awayLive || playState == .awayShot || playState == .homeFreethrow

        if canMove {
            var dx: CGFloat = 0
            var dy: CGFloat = 0
            if let lt = leftTouch {
                let curr = lt.location(in: self)
                dx = (curr.x - leftTouchPrev.x) * 1.8
                dy = (curr.y - leftTouchPrev.y) * 1.3
                leftTouchPrev = curr
                lastLeftInputTime = nowTime
            }
            let decayFactor = max(0, 1 - 3.5 * dt)
            leftImpulse.dx *= decayFactor
            leftImpulse.dy *= decayFactor
            if hypot(leftImpulse.dx, leftImpulse.dy) < 3 { leftImpulse = .zero }
            dx += leftImpulse.dx * dt
            dy += leftImpulse.dy * dt
            if abs(dx) > 0.3 || abs(dy) > 0.3 {
                player.position.x += dx
                player.position.y += dy
                clampToCourt(player)
                moving = true
                if abs(dx) > 0.5 { player.facing = dx > 0 ? 1 : -1 }
            }
            player.moveIntensity = moving ? min(1, hypot(dx, dy) / 5.0) : 0
        }

        let hasBall = possession == .home && (ball?.isHeld ?? false)
        if !moving && hasBall && nowTime - lastLeftInputTime > 0.8 { player.facing = 1 }
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
                showStealHint()
            }
            handler.updateLocomotion(moving: true, hasBall: true)
        case .dribbling(let until):
            handler.facing = 1
            handler.updateLocomotion(moving: false, hasBall: true)
            if now >= until {
                cpuState = .shooting
                hideStealHint()
                let dist = abs(rimX - handler.position.x)
                var error: CGFloat = (17 + dist * 0.05) * cpuShotMult
                var cpuContested = false
                if let humanID = activeHumanID, let human = players[humanID],
                   hypot(human.position.x - handler.position.x, human.position.y - handler.position.y) < 64 {
                    let lockdownBonus = humanID.character.stealBonus
                    error += 18 * (1 + lockdownBonus)
                    cpuContested = true
                }
                cpuBlockFill = 0
                contestResolved = false
                playState = .awayShot
                showCallout(
                    cpuContested ? "CONTESTED!" : "INCOMING!",
                    color: cpuContested
                        ? SKColor(red: 0.2, green: 0.83, blue: 0.2, alpha: 1)
                        : SKColor(red: 1.0, green: 0.75, blue: 0.2, alpha: 1)
                )
                HapticManager.impact(.light)
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
        let currentInt = Int(ceil(shotClockRemaining))
        if currentInt < lastShotClockInt, (1...3).contains(currentInt) {
            HapticManager.impact(.rigid)
        }
        lastShotClockInt = currentInt
        if shotClockRemaining <= 0 {
            showCallout("SHOT CLOCK!", color: .red)
            HapticManager.notification(.error)
            givePossession(to: .away)
        }
    }

    private func resolveExpiredFlight(_ now: TimeInterval) {
        guard playState == .homeShot || playState == .awayShot else { return }
        guard now > shotDeadline, pendingPossession == nil, let ball, !ball.isHeld else { return }
        if isFreethrowInFlight {
            // Free throw ball stuck — bail out, give next free throw or possession
            isFreethrowInFlight = false
            freethrowsRemaining -= 1
            if freethrowsRemaining > 0 {
                giveFreethrows(count: freethrowsRemaining)
            } else {
                scheduleGivePossession(to: .away, after: 0.1)
            }
            return
        }
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
    // Left half = move player (floating joystick, origin follows touch)
    // Bottom-right quadrant = action zone: pass/shoot/steal/block/foul

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            if let poster = posterNode {
                let p = touch.location(in: self)
                if hypot(p.x - poster.position.x, p.y - poster.position.y) < 20 {
                    toggleJerseyMod()
                    continue
                }
            }
            if phase == .ended {
                _ = resultCard?.handleTouch(touch)
                continue
            }
            guard phase == .playing else { continue }

            let p = touch.location(in: self)

            // 1) On-screen control buttons win hit-testing first.
            if let a = buttonA, a.hitTest(p) { handlePrimaryDown(touch); continue }
            if let b = buttonB, b.hitTest(p) { handleSecondaryDown(); continue }

            // 2) Left-thumb movement joystick (safe-area-aware boundary).
            let safeL = max(safeInsets.left, 0)
            let safeW = size.width - safeL - max(safeInsets.right, 0)
            let joyBoundary = safeL + safeW * 0.42
            if leftTouch == nil, p.x <= joyBoundary {
                leftTouch = touch
                leftTouchPrev = p
                leftTouchStartPos = p
                leftTouchStartTime = nowTime
                joystickNode?.begin(at: touch.location(in: uiLayer))
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches where touch == leftTouch {
            joystickNode?.move(to: touch.location(in: uiLayer))
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        finishTouches(touches, cancelled: false)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        finishTouches(touches, cancelled: true)
    }

    private func finishTouches(_ touches: Set<UITouch>, cancelled: Bool) {
        for touch in touches {
            if touch == shootButtonTouch {
                shootButtonTouch = nil
                buttonA?.setPressed(false)
                if cancelled {
                    isChargingShot = false
                    tapMeterFill = 0
                } else {
                    let captured = tapMeterFill        // capture BEFORE reset (load-bearing)
                    tapMeterFill = 0
                    isChargingShot = false
                    if playState == .homeFreethrow {
                        releaseFreethrow(charge: captured)
                    } else {
                        releaseShot(charge: captured)
                    }
                }
            }
            if touch == leftTouch {
                leftTouch = nil
                joystickNode?.end()
                let endPos = touch.location(in: self)
                let delta = CGPoint(x: endPos.x - leftTouchStartPos.x,
                                    y: endPos.y - leftTouchStartPos.y)
                let dist = hypot(delta.x, delta.y)
                let dur = max(0.01, nowTime - leftTouchStartTime)
                if dist > 28 && dur < 0.35 {
                    let speed = min(dist / CGFloat(dur), 900)
                    leftImpulse = CGVector(dx: (delta.x / dist) * speed * 0.55,
                                           dy: (delta.y / dist) * speed * 0.40)
                }
            }
        }
    }

    // MARK: - Control button dispatch

    private func handlePrimaryDown(_ touch: UITouch) {
        switch controlContext {
        case .offenseBallHoopLand, .freeThrow:
            // Hold-to-charge: MUST arm charging on press, else the meter stays at 0
            // and every shot releases short.
            shootButtonTouch = touch
            isChargingShot = true
            buttonA?.setPressed(true)
        case .offenseBallJumpBall:
            releaseJumpBallShot()
        case .defenseShot:
            attemptBlockOrFoul()
        case .defenseLive, .none:
            break
        }
    }

    private func handleSecondaryDown() {
        switch controlContext {
        case .offenseBallHoopLand, .offenseBallJumpBall:
            tryHumanPass()
        case .defenseLive:
            tryGestureSteal()   // self-guards distance + cooldown
        default:
            break
        }
    }

    private func refreshControlButtons() {
        // Translucent fills so the court shows through; the SHOOT/BLOCK ring conveys timing.
        let gold = SKColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 0.34)
        let blue = SKColor(red: 0.36, green: 0.55, blue: 1.0, alpha: 0.34)
        let red  = SKColor(red: 1.0, green: 0.32, blue: 0.30, alpha: 0.34)
        switch controlContext {
        case .offenseBallHoopLand:
            buttonA?.isHidden = false; buttonA?.configure(title: "SHOOT", fill: gold)
            buttonA?.setRing(fill: tapMeterFill)
            buttonB?.isHidden = false; buttonB?.configure(title: "PASS",  fill: blue)
        case .offenseBallJumpBall:
            buttonA?.isHidden = false; buttonA?.configure(title: "JUMP",  fill: gold)
            buttonA?.setRing(fill: nil)
            buttonB?.isHidden = false; buttonB?.configure(title: "PASS",  fill: blue)
        case .freeThrow:
            buttonA?.isHidden = false; buttonA?.configure(title: "SHOOT", fill: gold)
            buttonA?.setRing(fill: tapMeterFill)
            buttonB?.isHidden = true
        case .defenseLive:
            buttonA?.isHidden = true; buttonA?.setRing(fill: nil)
            buttonB?.isHidden = false; buttonB?.configure(title: "STEAL", fill: red)
        case .defenseShot:
            buttonA?.isHidden = false; buttonA?.configure(title: "BLOCK", fill: red)
            buttonA?.setRing(fill: cpuBlockFill, block: true)
            buttonB?.isHidden = true
        case .none:
            buttonA?.isHidden = true; buttonA?.setRing(fill: nil)
            buttonB?.isHidden = true
        }
        // If the context left the hold-charge state mid-press (e.g. shot fired), drop the tracked touch.
        if controlContext != .offenseBallHoopLand && controlContext != .freeThrow, shootButtonTouch != nil {
            shootButtonTouch = nil
            buttonA?.setPressed(false)
        }
    }

    // MARK: - Passes

    private func tryHumanPass() {
        guard playState == .homeLive, possession == .home,
              let humanID = activeHumanID,
              let mateID = homeIDs.first(where: { $0 != humanID }),
              let _ = players[mateID] else { return }

        showCallout("PASS!", color: SKColor(red: 0.4, green: 0.85, blue: 1.0, alpha: 1))
        HapticManager.impact(.medium)
        shakeWorld(4)
        players[humanID]?.setSelectionActive(false)
        players[mateID]?.setSelectionActive(true)
        activeHumanID = mateID
        // Cancel any in-progress SHOOT charge so the teammate doesn't inherit it.
        isChargingShot = false
        tapMeterFill = 0
        shootButtonTouch = nil
        buttonA?.setPressed(false)
        leftTouch = nil
        joystickNode?.end()
        leftImpulse = .zero
    }

    private func tryHumanBouncePass() {
        guard playState == .homeLive, possession == .home,
              let humanID = activeHumanID,
              let mateID = homeIDs.first(where: { $0 != humanID }),
              let _ = players[mateID] else { return }

        showCallout("BOUNCE PASS!", color: SKColor(red: 0.2, green: 0.75, blue: 1.0, alpha: 1))
        HapticManager.impact(.medium)
        shakeWorld(3)
        players[humanID]?.setSelectionActive(false)
        players[mateID]?.setSelectionActive(true)
        activeHumanID = mateID
        leftTouch = nil
        joystickNode?.end()
        leftImpulse = .zero
    }

    // MARK: - Steal / Foul / Block

    private func tryGestureSteal() {
        guard nowTime > humanStealCooldownUntil,
              let handlerID = cpuHandlerID, let handler = players[handlerID],
              let humanID = activeHumanID, let human = players[humanID] else { return }

        let dist = hypot(handler.position.x - human.position.x, handler.position.y - human.position.y)
        guard dist < 52 else {
            showCallout("GET CLOSER!", color: SKColor.white.withAlphaComponent(0.55))
            return
        }
        humanStealCooldownUntil = nowTime + 3.0

        let chance = (0.15 + human.heroID.character.stealBonus * 2.0) / (1.0 + difficulty.cpuStealRate * 0.5)
        if CGFloat.random(in: 0...1) < chance {
            showCallout("STEAL!", color: SKColor(red: 0.4, green: 0.95, blue: 0.5, alpha: 1))
            HapticManager.notification(.success)
            shakeWorld(7)
            givePossession(to: .home)
        } else {
            showCallout("NO GOOD", color: SKColor.white.withAlphaComponent(0.5))
            HapticManager.impact(.rigid)
        }
    }

    private func tryFoulNearDefender() {
        guard nowTime > humanStealCooldownUntil,
              let humanID = activeHumanID, let human = players[humanID] else { return }
        // Find any CPU player without the ball nearby
        for awayID in awayIDs where awayID != cpuHandlerID {
            guard let defender = players[awayID] else { continue }
            let dist = hypot(defender.position.x - human.position.x, defender.position.y - human.position.y)
            if dist < 40 {
                humanStealCooldownUntil = nowTime + 2.5
                showCallout("FOUL!", color: SKColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 1), big: true)
                HapticManager.notification(.error)
                shakeWorld(5)
                scheduleGivePossession(to: .away, after: 0.5)
                return
            }
        }
    }

    private func handleBlockAttempt() {
        guard playState == .awayShot else { return }
        guard cpuBlockFill >= greenLow && cpuBlockFill <= greenHigh else {
            showCallout(cpuBlockFill < greenLow ? "TOO EARLY!" : "TOO LATE!",
                        color: SKColor.white.withAlphaComponent(0.5))
            HapticManager.impact(.light)
            return
        }
        if CGFloat.random(in: 0...1) < 0.72 {
            pendingLaunch = nil
            ball?.missResolved = true  // prevent contact-based scoring if ball is mid-flight
            ball?.hold()
            showCallout("BLOCKED!", color: SKColor(red: 0.4, green: 0.95, blue: 0.5, alpha: 1), big: true)
            HapticManager.notification(.success)
            shakeWorld(7)
            scheduleGivePossession(to: .home, after: 0.35)
        } else {
            showCallout("MISSED IT!", color: SKColor.white.withAlphaComponent(0.60))
            HapticManager.impact(.rigid)
        }
    }

    /// BLOCK button (both modes) during the CPU shot. In-window timing -> a real
    /// block roll; mistimed while actually contesting the shooter -> shooting foul
    /// (2 free throws). Guarded by `contestResolved` so it fires at most once per shot.
    private func attemptBlockOrFoul() {
        // Close the contest window once the shot has resolved (scored/missed) or a
        // possession swap is already scheduled — otherwise a late BLOCK tap in the
        // 0.6–1.0s teardown gap wrongly awards a shooting foul.
        guard playState == .awayShot, !contestResolved,
              pendingPossession == nil,
              !(ball?.scoredThisFlight ?? false), !(ball?.missResolved ?? false) else { return }

        if cpuBlockFill >= greenLow && cpuBlockFill <= greenHigh {
            contestResolved = true
            handleBlockAttempt()
            return
        }

        // Mistimed -> auto foul ONLY if actually contesting the shooter.
        let contesting: Bool = {
            guard let hID = activeHumanID, let human = players[hID],
                  let sID = cpuHandlerID, let shooter = players[sID] else { return false }
            return hypot(human.position.x - shooter.position.x,
                         human.position.y - shooter.position.y) < 56
        }()
        if contesting {
            contestResolved = true
            showCallout(cpuBlockFill < greenLow ? "TOO EARLY — FOUL!" : "TOO LATE — FOUL!",
                        color: SKColor(red: 1, green: 0.32, blue: 0.30, alpha: 1), big: true)
            triggerShootingFoul()
        } else {
            showCallout(cpuBlockFill < greenLow ? "TOO EARLY!" : "TOO LATE!",
                        color: SKColor.white.withAlphaComponent(0.9))
            HapticManager.impact(.light)
        }
    }

    private func triggerShootingFoul() {
        guard playState == .awayShot else { return }
        pendingLaunch = nil
        ball?.missResolved = true
        ball?.hold()
        showCallout("SHOOTING FOUL! 2 FREE THROWS", color: SKColor(red: 1.0, green: 0.84, blue: 0, alpha: 1), big: true)
        HapticManager.notification(.success)
        shakeWorld(6)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.giveFreethrows(count: 2)
        }
    }

    private func giveFreethrows(count: Int) {
        guard phase == .playing else { return }
        freethrowsRemaining = count
        playState = .homeFreethrow
        possession = .home
        pendingLaunch = nil
        shotDeadline = .infinity
        ballTrailActive = false
        ball?.hold()
        ball?.setOnFire(false)
        resetTapMeter()
        hideStealHint()
        cpuState = .idle

        // Move active player to the free throw line
        let bandMid = (courtBandMinY + courtBandMaxY) / 2
        if let humanID = activeHumanID, let player = players[humanID] {
            player.position = CGPoint(x: max(playerMinX + 30, rimX - 190), y: bandMid)
        }
        showCallout("FREE THROW \(count)", color: SKColor(red: 1.0, green: 0.84, blue: 0, alpha: 1))
    }

    private func releaseShot(charge: CGFloat) {
        guard phase == .playing,
              playState == .homeLive,
              possession == .home,
              let id = activeHumanID,
              let player = players[id],
              let ball, ball.isHeld else { return }

        let activatedPower = registerBeatTiming(nowTime)

        let dist = abs(rimX - player.position.x)
        let beyondArc = player.position.x < threePointX
        let isLayup = player.position.x > rimX - 90
        var contested = false
        for awayID in awayIDs {
            if let defender = players[awayID],
               hypot(defender.position.x - player.position.x, defender.position.y - player.position.y) < 62 {
                contested = true
                break
            }
        }
        let error = shotError(charge: charge, dist: dist, beyondArc: beyondArc,
                              isLayup: isLayup, contested: contested, hero: player.heroID.character)

        // Shot type callout: ON FIRE overrides, then shot type, then contested, then perfect
        if contested {
            showCallout("CONTESTED!", color: SKColor(red: 1, green: 0.35, blue: 0.3, alpha: 1))
        } else if !activatedPower {
            if isLayup {
                showCallout("LAYUP!", color: SKColor(red: 1, green: 0.62, blue: 0.18, alpha: 1))
            } else if beyondArc {
                showCallout("PUMP 3!", color: SKColor(red: 1, green: 0.84, blue: 0, alpha: 1))
            } else if charge >= perfectLow && charge <= perfectHigh {
                showCallout(player.heroID.character.quip, color: SKColor(red: 1, green: 0.84, blue: 0, alpha: 1))
            }
        }

        playState = .homeShot
        player.playAnimationOnce(.shoot)
        pendingLaunch = PendingLaunch(
            at: nowTime + shootWindupDelay,
            team: .home,
            errorOffset: error
        )
        let isPerfect = !contested && !activatedPower && charge >= perfectLow && charge <= perfectHigh
        HapticManager.impact(isPerfect ? .heavy : .medium)
    }

    private func releaseFreethrow(charge: CGFloat) {
        guard phase == .playing,
              playState == .homeFreethrow,
              let id = activeHumanID,
              let player = players[id],
              let ball, ball.isHeld else { return }

        let error = shotError(charge: charge, dist: abs(rimX - player.position.x),
                              beyondArc: false, isLayup: false, contested: false,
                              hero: player.heroID.character)
        if charge >= perfectLow && charge <= perfectHigh {
            showCallout("SWISH!", color: SKColor(red: 1, green: 0.84, blue: 0, alpha: 1))
        }

        isFreethrowInFlight = true
        playState = .homeShot
        player.playAnimationOnce(.shoot)
        pendingLaunch = PendingLaunch(
            at: nowTime + shootWindupDelay,
            team: .home,
            errorOffset: error
        )
        HapticManager.impact(.medium)
    }

    /// JumpBall mode: tap JUMP -> the shot auto-releases at the jump apex. No charge
    /// meter; quality comes from openness (nearest defender) plus a deterministic
    /// spread. Reuses the existing PendingLaunch flight path and on-beat power system.
    private func releaseJumpBallShot() {
        guard phase == .playing, playState == .homeLive, possession == .home,
              pendingLaunch == nil,
              let id = activeHumanID, let player = players[id],
              let ball, ball.isHeld else { return }

        let activatedPower = registerBeatTiming(nowTime)

        let dist = abs(rimX - player.position.x)
        let beyondArc = player.position.x < threePointX
        let isLayup = player.position.x > rimX - 90
        var nearest: CGFloat = .greatestFiniteMagnitude
        for awayID in awayIDs {
            if let d = players[awayID] {
                nearest = min(nearest, hypot(d.position.x - player.position.x,
                                             d.position.y - player.position.y))
            }
        }
        let contested = nearest < 62

        let autoCharge: CGFloat = (perfectHigh + greenHigh) / 2   // strictly inside green (never perfect) on all difficulties
        let accuracy = shotAccuracy(charge: autoCharge, dist: dist, beyondArc: beyondArc,
                                    isLayup: isLayup, contested: contested,
                                    hero: player.heroID.character)

        // Deterministic error: lower accuracy -> bigger miss; sign alternates; golden-ratio jitter (no RNG).
        jumpBallShotCount += 1
        let n = jumpBallShotCount
        let sign: CGFloat = (n % 2 == 0) ? 1 : -1
        let jitter = (CGFloat(n) * 0.61803398875).truncatingRemainder(dividingBy: 1) - 0.5
        let errorOffset = sign * (1 - accuracy) * 60 + jitter * 6

        if !activatedPower {
            showCallout(contested ? "CONTESTED!" : "OPEN LOOK!",
                        color: contested ? SKColor(red: 1, green: 0.35, blue: 0.3, alpha: 1)
                                         : SKColor(red: 1, green: 0.84, blue: 0, alpha: 1))
        }
        HapticManager.impact(contested ? .medium : .heavy)

        playState = .homeShot
        player.playAnimationOnce(.shoot)
        pendingLaunch = PendingLaunch(at: nowTime + shootWindupDelay, team: .home, errorOffset: errorOffset)
    }

    /// Returns an error offset for the ball's landing point relative to rim center.
    /// Positive = long (toward backboard/over); negative = short (early rim/airball).
    /// Perfect zone returns near-zero; over-green biases long; under biases short.
    /// Deterministic accuracy model (0.05...1.0), shared by the charge-meter shot
    /// and the JumpBall auto-shot. No RNG here — callers add their own scatter.
    private func shotAccuracy(charge: CGFloat, dist: CGFloat, beyondArc: Bool,
                              isLayup: Bool, contested: Bool, hero: HalfCourtHero) -> CGFloat {
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
        if isLayup { accuracy += hero.closeBonus + 0.08 }
        else if !beyondArc { accuracy += hero.closeBonus }
        if isPowered { accuracy += 0.15 }
        return max(0.05, min(1.0, accuracy))
    }

    private func shotError(charge: CGFloat, dist: CGFloat, beyondArc: Bool,
                           isLayup: Bool, contested: Bool, hero: HalfCourtHero) -> CGFloat {
        let c = min(charge, 1.2)
        let overGreen = c > greenHigh
        let underGreen = c < greenLow
        let accuracy = shotAccuracy(charge: charge, dist: dist, beyondArc: beyondArc,
                                    isLayup: isLayup, contested: contested, hero: hero)

        if CGFloat.random(in: 0...1) < accuracy {
            return CGFloat.random(in: 2...5) // good shot — tiny random scatter
        }
        // Miss: direction depends on timing
        let missRange: CGFloat = CGFloat.random(in: 22...52)
        if overGreen {
            return +missRange  // too late = goes long (backboard or over)
        } else if underGreen {
            return -missRange  // too early = falls short (early rim or airball)
        }
        return CGFloat.random(in: -missRange...missRange)
    }

    @discardableResult
    private func registerBeatTiming(_ now: TimeInterval) -> Bool {
        let delta = nearestBeatDelta(now)
        if delta <= onBeatWindow {
            onBeatStreak += 1
            if onBeatStreak >= 3 {
                onBeatStreak = 0
                activatePowerUp(now)
                return true
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
        return false
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

        // Free throw make: 1 point, continue free throw sequence
        if isFreethrowInFlight {
            isFreethrowInFlight = false
            rattleRim()
            homeScore += 1
            freethrowsRemaining -= 1
            showCallout("+1 FREE THROW", color: SKColor(red: 1.0, green: 0.84, blue: 0, alpha: 1), big: false)
            HapticManager.notification(.success)
            shakeWorld(4)
            if freethrowsRemaining > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                    self?.giveFreethrows(count: self?.freethrowsRemaining ?? 0)
                }
            } else {
                checkForGameEnd(afterTeam: .home, after: 0.8)
            }
            return
        }

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

        // Game/match point tension callout (fires exactly once when score first hits 10)
        if homeScore == winScore - 1 {
            let isMatchPoint = homeSeriesWins == seriesWinTarget - 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
                guard let self, self.homeScore == self.winScore - 1 else { return }
                self.showCallout(isMatchPoint ? "MATCH POINT!" : "GAME POINT!",
                                 color: SKColor(red: 1.0, green: 0.85, blue: 0.1, alpha: 1), big: false)
                HapticManager.impact(.heavy)
            }
        } else if awayScore == winScore - 1 {
            let isMatchPoint = awaySeriesWins == seriesWinTarget - 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
                guard let self, self.awayScore == self.winScore - 1 else { return }
                self.showCallout(isMatchPoint ? "CPU MATCH PT" : "CPU GAME PT",
                                 color: SKColor(red: 1.0, green: 0.42, blue: 0.21, alpha: 1), big: false)
            }
        }

        checkForGameEnd(afterTeam: ball.shotTeam, after: 1.0)
    }

    private func checkForGameEnd(afterTeam: HalfCourtTeam, after delay: TimeInterval) {
        if homeScore >= winScore || awayScore >= winScore {
            if homeScore >= winScore {
                homeSeriesWins += 1
                let isMatch = homeSeriesWins >= seriesWinTarget
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
                    guard let self else { return }
                    self.showCallout(isMatch ? "MATCH!" : "GAME!", color: SKColor(red: 1.0, green: 0.86, blue: 0.0, alpha: 1), big: true)
                    HapticManager.impact(.heavy)
                }
            } else {
                awaySeriesWins += 1
                let isMatch = awaySeriesWins >= seriesWinTarget
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
                    guard let self else { return }
                    self.showCallout(isMatch ? "MATCH OVER" : "CPU GAME", color: SKColor(red: 1.0, green: 0.42, blue: 0.21, alpha: 1), big: false)
                }
            }
            pendingResolveAt = nowTime + 1.0
        } else {
            scheduleGivePossession(to: afterTeam == .home ? .away : .home, after: delay)
        }
    }

    private func handleFloorContact() {
        guard let ball, !ball.isHeld, !ball.scoredThisFlight, !ball.missResolved else { return }
        guard playState == .homeShot || playState == .awayShot else { return }
        ball.missResolved = true

        // Free throw miss: continue sequence or hand off
        if isFreethrowInFlight {
            isFreethrowInFlight = false
            freethrowsRemaining -= 1
            showCallout("NO GOOD", color: SKColor.white.withAlphaComponent(0.65))
            HapticManager.impact(.medium)
            if freethrowsRemaining > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                    self?.giveFreethrows(count: self?.freethrowsRemaining ?? 0)
                }
            } else {
                scheduleGivePossession(to: .away, after: 0.8)
            }
            return
        }

        if ball.shotTeam == .home {
            showCallout(["MISS!", "OFF THE RIM!", "NO GOOD!", "RATTLED OUT!", "BRICK!"].randomElement() ?? "MISS!",
                        color: SKColor.white.withAlphaComponent(0.6))
            HapticManager.impact(.medium)
        } else {
            showCallout(["BRICKED!", "WALLED OFF!", "BLOCKED OUT!", "NOT TODAY!"].randomElement() ?? "BRICKED!",
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
                shakeWorld(14)
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
                    // phase must be .playing before resetMatch so givePossession
                    // doesn't short-circuit its guard check
                    self.phase = .playing
                    self.resetMatch()
                }
            },
            onRematch: isSeriesOver ? { [weak self] in self?.startSeries() } : nil
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

    // MARK: - Steal hint

    private func showStealHint() {
        stealHintNode?.removeFromParent()
        let hint = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        hint.text = "SWIPE \u{2192} STEAL"
        hint.fontSize = 14
        hint.fontColor = SKColor(red: 0.4, green: 0.95, blue: 0.5, alpha: 1)
        hint.horizontalAlignmentMode = .right
        hint.position = CGPoint(x: size.width - 18, y: size.height * 0.30)
        hint.zPosition = 195
        hint.alpha = 0
        fxLayer.addChild(hint)
        stealHintNode = hint

        hint.run(SKAction.sequence([
            SKAction.fadeAlpha(to: 0.85, duration: 0.22),
            SKAction.wait(forDuration: 1.0),
            SKAction.group([
                SKAction.fadeOut(withDuration: 0.45),
                SKAction.moveBy(x: 14, y: 0, duration: 0.45),
            ]),
            SKAction.removeFromParent(),
        ]))
    }

    private func hideStealHint() {
        stealHintNode?.removeAllActions()
        stealHintNode?.removeFromParent()
        stealHintNode = nil
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

    // MARK: - Jersey mod

    private func toggleJerseyMod() {
        nbaJerseysEnabled.toggle()
        UserDefaults.standard.set(nbaJerseysEnabled, forKey: "hch_nba_jerseys_mod")

        if let poster = posterNode, let bg = poster.children.first as? SKShapeNode {
            bg.strokeColor = nbaJerseysEnabled
                ? SKColor(red: 1.0, green: 0.85, blue: 0.0, alpha: 1.0)
                : SKColor(red: 1.0, green: 0.55, blue: 0.0, alpha: 0.85)
            bg.lineWidth = nbaJerseysEnabled ? 3.5 : 2.0
            let pulse = SKAction.sequence([
                SKAction.scale(to: 1.3, duration: 0.08),
                SKAction.scale(to: 0.92, duration: 0.08),
                SKAction.scale(to: 1.0, duration: 0.06),
            ])
            poster.run(pulse)
        }

        let msg = nbaJerseysEnabled ? "NBA JERSEYS ON" : "NBA JERSEYS OFF"
        let color = nbaJerseysEnabled
            ? SKColor(red: 0.0, green: 0.58, blue: 0.9, alpha: 1)
            : SKColor.white.withAlphaComponent(0.65)
        showCallout(msg, color: color)

        for player in players.values {
            player.reloadSprite(nbaJerseys: nbaJerseysEnabled)
        }
    }
}

// MARK: - Tap-pump shot meter (horizontal bar across top of screen)

enum TapMeterMode { case shoot, block }

@MainActor
final class TapShotMeterNode: SKNode {
    private let barHeight: CGFloat = 28
    private var barWidth: CGFloat
    private var isVertical = false
    private var greenLow: CGFloat
    private var greenHigh: CGFloat
    private var perfectLow: CGFloat
    private var perfectHigh: CGFloat

    private let background = SKShapeNode()
    private let fillNode = SKShapeNode()
    private let greenZone = SKShapeNode()
    private let perfectZone = SKShapeNode()
    private let flashOverlay = SKShapeNode()
    private let modeLabel = SKLabelNode()
    private let beatRing = SKShapeNode()

    init(barWidth: CGFloat, greenLow: CGFloat, greenHigh: CGFloat, perfectLow: CGFloat, perfectHigh: CGFloat) {
        self.barWidth = barWidth
        self.greenLow = greenLow
        self.greenHigh = greenHigh
        self.perfectLow = perfectLow
        self.perfectHigh = perfectHigh
        super.init()
        setup()
    }

    required init?(coder aDecoder: NSCoder) { fatalError() }

    func layout(barWidth: CGFloat) {
        self.barWidth = barWidth
        rebuildZones()
    }

    func reconfigure(greenLow: CGFloat, greenHigh: CGFloat, perfectLow: CGFloat, perfectHigh: CGFloat) {
        self.greenLow = greenLow
        self.greenHigh = greenHigh
        self.perfectLow = perfectLow
        self.perfectHigh = perfectHigh
        rebuildZones()
    }

    private func setup() {
        background.fillColor = SKColor.black.withAlphaComponent(0.85)
        background.strokeColor = SKColor.white.withAlphaComponent(0.70)
        background.lineWidth = 2
        addChild(background)

        fillNode.strokeColor = .clear
        addChild(fillNode)

        greenZone.fillColor = SKColor(red: 0.2, green: 0.83, blue: 0.2, alpha: 0.70)
        greenZone.strokeColor = .clear
        addChild(greenZone)

        perfectZone.fillColor = SKColor(red: 1, green: 0.84, blue: 0, alpha: 0.85)
        perfectZone.strokeColor = .clear
        addChild(perfectZone)

        flashOverlay.fillColor = .white
        flashOverlay.strokeColor = .clear
        flashOverlay.alpha = 0
        addChild(flashOverlay)

        modeLabel.fontName = "AvenirNext-Bold"
        modeLabel.fontSize = 10
        modeLabel.fontColor = SKColor.white.withAlphaComponent(0.55)
        modeLabel.verticalAlignmentMode = .center
        modeLabel.horizontalAlignmentMode = .right
        modeLabel.text = "SHOOT"
        addChild(modeLabel)

        beatRing.strokeColor = SKColor(red: 1, green: 0.84, blue: 0, alpha: 0.9)
        beatRing.lineWidth = 2
        beatRing.fillColor = .clear
        beatRing.alpha = 0
        addChild(beatRing)

        rebuildZones()
    }

    private func rebuildZones() {
        let w = barWidth
        let h = barHeight
        let r: CGFloat = h / 2

        background.path = CGPath(roundedRect: CGRect(x: -w / 2, y: -h / 2, width: w, height: h),
                                  cornerWidth: r, cornerHeight: r, transform: nil)

        let gx = -w / 2 + greenLow * w
        let gw = (greenHigh - greenLow) * w
        greenZone.path = CGPath(rect: CGRect(x: gx, y: -h / 2, width: gw, height: h), transform: nil)

        let px = -w / 2 + perfectLow * w
        let pw = (perfectHigh - perfectLow) * w
        perfectZone.path = CGPath(rect: CGRect(x: px, y: -h / 2, width: pw, height: h), transform: nil)

        flashOverlay.path = CGPath(roundedRect: CGRect(x: -w / 2, y: -h / 2, width: w, height: h),
                                    cornerWidth: r, cornerHeight: r, transform: nil)

        beatRing.path = CGPath(roundedRect: CGRect(x: -w / 2 - 4, y: -h / 2 - 4, width: w + 8, height: h + 8),
                                cornerWidth: r + 4, cornerHeight: r + 4, transform: nil)

        if isVertical {
            // After CCW 90° rotation, local -x maps to screen "below center"
            modeLabel.position = CGPoint(x: -w / 2 - 28, y: 0)
            modeLabel.zRotation = -.pi / 2
            modeLabel.horizontalAlignmentMode = .center
        } else {
            modeLabel.position = CGPoint(x: w / 2 - 8, y: 0)
            modeLabel.zRotation = 0
            modeLabel.horizontalAlignmentMode = .right
        }

        setFill(0, mode: .shoot)
    }

    func setVertical(_ vertical: Bool) {
        isVertical = vertical
        rebuildZones()
    }

    func setFill(_ fill: CGFloat, mode: TapMeterMode) {
        let w = barWidth
        let h = barHeight
        let r: CGFloat = h / 2
        let clamped = min(fill, 1.0)

        if clamped <= 0.01 {
            fillNode.path = nil
        } else {
            let fw = clamped * w
            fillNode.path = CGPath(roundedRect: CGRect(x: -w / 2, y: -h / 2, width: fw, height: h),
                                    cornerWidth: min(r, fw / 2), cornerHeight: min(r, fw / 2), transform: nil)
        }

        switch mode {
        case .shoot:
            modeLabel.text = "SHOOT"
            if fill >= perfectLow && fill <= perfectHigh {
                fillNode.fillColor = SKColor(red: 1, green: 0.84, blue: 0, alpha: 1)
            } else if fill >= greenLow && fill <= greenHigh {
                fillNode.fillColor = SKColor(red: 0.2, green: 0.83, blue: 0.2, alpha: 1)
            } else if fill > greenHigh {
                fillNode.fillColor = SKColor(red: 1, green: 0.25, blue: 0.2, alpha: 1)
            } else {
                fillNode.fillColor = SKColor(red: 1, green: 0.84, blue: 0, alpha: 0.65)
            }
        case .block:
            modeLabel.text = "BLOCK"
            if fill >= greenLow && fill <= greenHigh {
                fillNode.fillColor = SKColor(red: 0.4, green: 0.95, blue: 0.5, alpha: 1)
            } else if fill > greenHigh {
                fillNode.fillColor = SKColor(red: 1, green: 0.35, blue: 0.2, alpha: 1)
            } else {
                fillNode.fillColor = SKColor(red: 0.85, green: 0.55, blue: 0.15, alpha: 1)
            }
        }
    }

    func pumpFlash() {
        flashOverlay.removeAllActions()
        flashOverlay.alpha = 0.35
        flashOverlay.run(SKAction.fadeOut(withDuration: 0.12))
    }

    func beatPulse() {
        beatRing.removeAllActions()
        beatRing.alpha = 0.9
        beatRing.setScale(1)
        beatRing.run(SKAction.group([
            SKAction.scale(to: 1.08, duration: 0.28),
            SKAction.fadeOut(withDuration: 0.28),
        ]))
    }
}

// MARK: - Legacy shoot button (kept for reference, no longer active)

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

// MARK: - On-screen control button (context-relabeled: SHOOT/JUMP/BLOCK, PASS/STEAL)

@MainActor
final class ControlButtonNode: SKNode {
    let radius: CGFloat
    private let bg = SKShapeNode()
    private let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")

    // Optional charge/timing ring drawn just outside the button (replaces the old wide meter bar).
    private let ringRadius: CGFloat
    private let greenArc = SKShapeNode()
    private let perfectArc = SKShapeNode()
    private let fillArc = SKShapeNode()
    private let beatRing = SKShapeNode()
    private let startAngle: CGFloat = .pi * 7 / 6   // 210°, lower-left
    private let sweep: CGFloat = .pi * 4 / 3        // 240°
    private var greenLow: CGFloat = 0.52
    private var greenHigh: CGFloat = 0.76
    private var perfectLow: CGFloat = 0.59
    private var perfectHigh: CGFloat = 0.69

    init(radius: CGFloat) {
        self.radius = radius
        self.ringRadius = radius + 7
        super.init()
        bg.path = CGPath(ellipseIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2), transform: nil)
        bg.strokeColor = SKColor(white: 1, alpha: 0.7)
        bg.lineWidth = 2
        addChild(bg)

        for arc in [greenArc, perfectArc, fillArc] {
            arc.fillColor = .clear
            arc.lineWidth = 5
            arc.lineCap = .round
            arc.isHidden = true
            addChild(arc)
        }
        greenArc.strokeColor = SKColor(red: 0.2, green: 0.83, blue: 0.2, alpha: 0.45)
        perfectArc.strokeColor = SKColor(red: 1, green: 0.84, blue: 0, alpha: 0.7)

        beatRing.path = CGPath(ellipseIn: CGRect(x: -ringRadius, y: -ringRadius,
                                                 width: ringRadius * 2, height: ringRadius * 2), transform: nil)
        beatRing.strokeColor = SKColor(red: 1, green: 0.84, blue: 0, alpha: 0.9)
        beatRing.lineWidth = 2.5
        beatRing.fillColor = .clear
        beatRing.alpha = 0
        addChild(beatRing)

        label.fontSize = radius * 0.40
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        addChild(label)
        zPosition = 122
    }
    required init?(coder: NSCoder) { fatalError() }

    private func angle(for charge: CGFloat) -> CGFloat { startAngle - sweep * min(max(charge, 0), 1) }
    private func arcPath(from a: CGFloat, to b: CGFloat) -> CGPath {
        let p = CGMutablePath()
        p.addArc(center: .zero, radius: ringRadius, startAngle: a, endAngle: b, clockwise: true)
        return p
    }

    func configure(title: String, fill: SKColor) {
        if label.text != title { label.text = title }
        bg.fillColor = fill
    }

    func setPressed(_ pressed: Bool) { setScale(pressed ? 0.92 : 1.0) }

    /// One beat of the song: subtle scale bump + gold ring flash (112 BPM cue).
    func beatPulse() {
        bg.removeAction(forKey: "beatPulse")
        let up = SKAction.scale(to: 1.06, duration: 0.10); up.timingMode = .easeOut
        let down = SKAction.scale(to: 1.0, duration: 0.20); down.timingMode = .easeIn
        bg.run(.sequence([up, down]), withKey: "beatPulse")
        beatRing.removeAllActions()
        beatRing.setScale(1.0)
        beatRing.alpha = 0.9
        beatRing.run(.group([.scale(to: 1.12, duration: 0.30), .fadeOut(withDuration: 0.30)]))
    }

    /// Set the green/perfect timing windows the ring should display.
    func configureRing(greenLow: CGFloat, greenHigh: CGFloat, perfectLow: CGFloat, perfectHigh: CGFloat) {
        self.greenLow = greenLow; self.greenHigh = greenHigh
        self.perfectLow = perfectLow; self.perfectHigh = perfectHigh
        greenArc.path = arcPath(from: angle(for: greenLow), to: angle(for: greenHigh))
        perfectArc.path = arcPath(from: angle(for: perfectLow), to: angle(for: perfectHigh))
    }

    /// `fill` nil hides the ring; otherwise draws the charge fill. `block` = defense block-timing (green window only).
    func setRing(fill: CGFloat?, block: Bool = false) {
        guard let fill else {
            greenArc.isHidden = true; perfectArc.isHidden = true; fillArc.isHidden = true
            return
        }
        greenArc.isHidden = false
        perfectArc.isHidden = block
        fillArc.isHidden = fill <= 0.01
        fillArc.path = arcPath(from: startAngle, to: angle(for: fill))
        if block {
            fillArc.strokeColor = (fill >= greenLow && fill <= greenHigh)
                ? SKColor(red: 0.4, green: 0.95, blue: 0.5, alpha: 1)
                : (fill > greenHigh ? SKColor(red: 1, green: 0.35, blue: 0.2, alpha: 1)
                                    : SKColor(red: 0.9, green: 0.6, blue: 0.15, alpha: 1))
        } else if fill >= perfectLow && fill <= perfectHigh {
            fillArc.strokeColor = SKColor(red: 1, green: 0.84, blue: 0, alpha: 1)
        } else if fill >= greenLow && fill <= greenHigh {
            fillArc.strokeColor = SKColor(red: 0.2, green: 0.83, blue: 0.2, alpha: 1)
        } else if fill > greenHigh {
            fillArc.strokeColor = SKColor(red: 1, green: 0.25, blue: 0.2, alpha: 1)
        } else {
            fillArc.strokeColor = SKColor(white: 1, alpha: 0.9)
        }
    }

    /// Hit-test in scene space (uiLayer sits at the scene origin, so they coincide).
    func hitTest(_ pt: CGPoint) -> Bool {
        guard !isHidden else { return false }
        let dx = pt.x - position.x, dy = pt.y - position.y
        let r = radius + 8   // slop
        return dx * dx + dy * dy <= r * r
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

    func beatFlash() {
        run(.sequence([.fadeAlpha(to: 0.6, duration: 0.10), .fadeAlpha(to: 1.0, duration: 0.10)]))
    }

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
