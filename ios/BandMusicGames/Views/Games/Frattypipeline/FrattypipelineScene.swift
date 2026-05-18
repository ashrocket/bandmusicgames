import SpriteKit

enum FrattypipelineQuestState: Equatable {
    case findStage
    case barkOnBeat
    case collectPatch
    case complete

    var title: String {
        switch self {
        case .findStage:
            return "Find The Stage"
        case .barkOnBeat:
            return "Bark On Beat"
        case .collectPatch:
            return "Collect The Patch"
        case .complete:
            return "Quad Awake"
        }
    }

    var detail: String {
        switch self {
        case .findStage:
            return "Move Groucho to the speakers."
        case .barkOnBeat:
            return "Tap BARK inside the gold beat window."
        case .collectPatch:
            return "Grab the glowing campus patch."
        case .complete:
            return "The crowd heard Groucho."
        }
    }
}

enum FrattypipelineTile: CaseIterable {
    case grass
    case path
    case stage
    case water
}

struct FrattypipelineBeatClock {
    let bpm: Double
    private(set) var time: TimeInterval = 0

    var beatLength: TimeInterval {
        60.0 / bpm
    }

    var phase: Double {
        let raw = time.truncatingRemainder(dividingBy: beatLength) / beatLength
        return raw < 0 ? raw + 1 : raw
    }

    var isInHitWindow: Bool {
        phase < 0.18 || phase > 0.82
    }

    var energy: CGFloat {
        CGFloat(max(0, 1 - min(phase, 1 - phase) / 0.18))
    }

    mutating func advance(by delta: TimeInterval) {
        time += max(0, delta)
    }
}

final class FrattypipelineScene: SKScene, ObservableObject {
    static let mapWidth = 12
    static let mapHeight = 9
    static let tileWidth: CGFloat = 76
    static let tileHeight: CGFloat = 38

    @Published private(set) var questState: FrattypipelineQuestState = .findStage
    @Published private(set) var beatPhase: Double = 0
    @Published private(set) var lastBarkWasOnBeat = false
    @Published private(set) var barkCount = 0

    let input = FrattypipelineInputController()
    var autoplayDemo = false

    private var beatClock = FrattypipelineBeatClock(bpm: 101)
    private var lastUpdateTime: TimeInterval?
    private var grouchoGrid = CGPoint(x: 1.6, y: 6.8)
    private var patchGrid = CGPoint(x: 8.4, y: 5.8)
    private var stageGrid = CGPoint(x: 6.5, y: 3.9)

    private let worldNode = SKNode()
    private let avatarNode = SKNode()
    private let pulseNode = SKNode()
    private let patchNode = SKNode()
    private var reactiveNodes: [SKNode] = []
    private var stageTileNodes: [SKShapeNode] = []
    private var stageLit = false

    static func make() -> FrattypipelineScene {
        let scene = FrattypipelineScene(size: CGSize(width: 900, height: 620))
        scene.scaleMode = .resizeFill
        scene.backgroundColor = UIColor(red: 0.08, green: 0.10, blue: 0.09, alpha: 1)
        return scene
    }

    override func didMove(to view: SKView) {
        removeAllChildren()
        worldNode.removeAllChildren()
        reactiveNodes.removeAll()
        stageTileNodes.removeAll()
        addChild(worldNode)
        addChild(pulseNode)
        buildWorld()
        buildGroucho()
        buildPatch()
        updateCameraLayout()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        updateCameraLayout()
    }

    func resetPrototype() {
        questState = .findStage
        barkCount = 0
        stageLit = false
        refreshStageTiles()
        lastBarkWasOnBeat = false
        grouchoGrid = CGPoint(x: 1.6, y: 6.8)
        patchNode.isHidden = true
        input.reset()
        for node in reactiveNodes {
            node.removeAllActions()
            node.setScale(1)
            node.alpha = 1
        }
        updateGrouchoPosition()
    }

    override func update(_ currentTime: TimeInterval) {
        let delta = lastUpdateTime.map { min(0.05, currentTime - $0) } ?? 0
        lastUpdateTime = currentTime
        beatClock.advance(by: delta)
        beatPhase = beatClock.phase

        if autoplayDemo {
            updateAutoplay(delta: delta)
        } else {
            updateMovement(delta: delta)
        }
        updateQuestProximity()
        if input.consumeBark() {
            handleBark()
        }
        updateGrouchoPosition()
        updatePatchState()
    }

    private func updateAutoplay(delta: TimeInterval) {
        switch questState {
        case .findStage:
            moveGroucho(toward: CGPoint(x: 5.8, y: 4.4), delta: delta, speed: 2.8)
        case .barkOnBeat:
            if beatClock.isInHitWindow {
                input.triggerBark()
            }
        case .collectPatch:
            moveGroucho(toward: patchGrid, delta: delta, speed: 2.6)
        case .complete:
            if beatClock.isInHitWindow && barkCount < 5 {
                input.triggerBark()
            }
        }
    }

    private func moveGroucho(toward target: CGPoint, delta: TimeInterval, speed: CGFloat) {
        let dx = target.x - grouchoGrid.x
        let dy = target.y - grouchoGrid.y
        let length = hypot(dx, dy)
        guard length > 0.05 else { return }

        let step = min(length, speed * delta)
        grouchoGrid = CGPoint(
            x: grouchoGrid.x + (dx / length) * step,
            y: grouchoGrid.y + (dy / length) * step
        )
    }

    private func updateMovement(delta: TimeInterval) {
        let direction = input.joystick
        let magnitude = min(1, hypot(direction.dx, direction.dy))
        guard magnitude > 0.02 else { return }

        let speed: CGFloat = 2.2
        let next = CGPoint(
            x: grouchoGrid.x + direction.dx * speed * delta,
            y: grouchoGrid.y + direction.dy * speed * delta
        )

        guard next.x >= 0.4,
              next.x <= CGFloat(Self.mapWidth) - 1.2,
              next.y >= 0.5,
              next.y <= CGFloat(Self.mapHeight) - 1.0
        else { return }

        grouchoGrid = next
    }

    private func updateQuestProximity() {
        if questState == .findStage && distance(grouchoGrid, stageGrid) < 1.5 {
            questState = .barkOnBeat
        }

        if questState == .collectPatch && distance(grouchoGrid, patchGrid) < 0.7 {
            questState = .complete
            patchNode.isHidden = true
            runCompletionBurst()
        }
    }

    private func handleBark() {
        barkCount += 1
        lastBarkWasOnBeat = beatClock.isInHitWindow
        drawBarkPulse(onBeat: lastBarkWasOnBeat)

        guard questState == .barkOnBeat else {
            nudgeWorld(onBeat: lastBarkWasOnBeat)
            return
        }

        if lastBarkWasOnBeat {
            stageLit = true
            refreshStageTiles()
            questState = .collectPatch
            patchNode.isHidden = false
            nudgeWorld(onBeat: true)
        } else {
            nudgeWorld(onBeat: false)
        }
    }

    private func buildWorld() {
        for y in 0..<Self.mapHeight {
            for x in 0..<Self.mapWidth {
                let tile = tileType(x: x, y: y)
                let node = diamondNode(fill: color(for: tile), stroke: UIColor.black.withAlphaComponent(0.28))
                node.position = iso(x: CGFloat(x), y: CGFloat(y))
                node.zPosition = CGFloat(x + y)
                if tile == .stage {
                    stageTileNodes.append(node)
                }
                worldNode.addChild(node)
            }
        }

        addProp(kind: .tree, at: CGPoint(x: 1.0, y: 1.7))
        addProp(kind: .tree, at: CGPoint(x: 9.9, y: 2.0))
        addProp(kind: .bush, at: CGPoint(x: 3.3, y: 2.1))
        addProp(kind: .bush, at: CGPoint(x: 10.3, y: 6.2))
        addProp(kind: .lamp, at: CGPoint(x: 5.4, y: 2.5))
        addProp(kind: .lamp, at: CGPoint(x: 7.6, y: 5.4))
        addProp(kind: .speaker, at: CGPoint(x: 6.0, y: 4.1))
        addProp(kind: .speaker, at: CGPoint(x: 7.3, y: 4.2))
        addProp(kind: .npc, at: CGPoint(x: 5.2, y: 5.3))
        addProp(kind: .npc, at: CGPoint(x: 7.2, y: 5.7))
        addProp(kind: .npc, at: CGPoint(x: 8.3, y: 4.7))
        addProp(kind: .sign, at: CGPoint(x: 3.9, y: 6.5))
    }

    private enum PropKind {
        case tree
        case bush
        case lamp
        case speaker
        case npc
        case sign
    }

    private func addProp(kind: PropKind, at grid: CGPoint) {
        let container = SKNode()
        container.position = iso(x: grid.x, y: grid.y)
        container.zPosition = 200 + grid.x + grid.y

        switch kind {
        case .tree:
            let trunk = SKShapeNode(rectOf: CGSize(width: 12, height: 34), cornerRadius: 3)
            trunk.fillColor = UIColor(red: 0.40, green: 0.27, blue: 0.17, alpha: 1)
            trunk.strokeColor = .clear
            trunk.position = CGPoint(x: 0, y: 20)
            let crown = SKShapeNode(circleOfRadius: 31)
            crown.fillColor = UIColor(red: 0.28, green: 0.53, blue: 0.32, alpha: 1)
            crown.strokeColor = .clear
            crown.position = CGPoint(x: 0, y: 54)
            container.addChild(trunk)
            container.addChild(crown)
        case .bush:
            for offset in [-14, 0, 14] {
                let leaf = SKShapeNode(circleOfRadius: 13)
                leaf.fillColor = UIColor(red: 0.31, green: 0.58, blue: 0.31, alpha: 1)
                leaf.strokeColor = .clear
                leaf.position = CGPoint(x: CGFloat(offset), y: 18)
                container.addChild(leaf)
            }
        case .lamp:
            let pole = SKShapeNode(rectOf: CGSize(width: 5, height: 58), cornerRadius: 2)
            pole.fillColor = UIColor(red: 0.31, green: 0.28, blue: 0.22, alpha: 1)
            pole.strokeColor = .clear
            pole.position = CGPoint(x: 0, y: 30)
            let bulb = SKShapeNode(circleOfRadius: 10)
            bulb.fillColor = UIColor(red: 0.95, green: 0.72, blue: 0.32, alpha: 1)
            bulb.strokeColor = .clear
            bulb.position = CGPoint(x: 0, y: 64)
            let glow = SKShapeNode(circleOfRadius: 38)
            glow.fillColor = UIColor(red: 0.95, green: 0.72, blue: 0.32, alpha: 0.14)
            glow.strokeColor = .clear
            glow.position = bulb.position
            container.addChild(glow)
            container.addChild(pole)
            container.addChild(bulb)
            reactiveNodes.append(glow)
        case .speaker:
            let body = SKShapeNode(rectOf: CGSize(width: 30, height: 52), cornerRadius: 4)
            body.fillColor = UIColor(red: 0.12, green: 0.12, blue: 0.11, alpha: 1)
            body.strokeColor = UIColor(white: 0.45, alpha: 1)
            body.position = CGPoint(x: 0, y: 28)
            container.addChild(body)
            for y in [17, 39] {
                let cone = SKShapeNode(circleOfRadius: 9)
                cone.fillColor = UIColor(white: 0.03, alpha: 1)
                cone.strokeColor = .clear
                cone.position = CGPoint(x: 0, y: CGFloat(y))
                container.addChild(cone)
            }
            reactiveNodes.append(container)
        case .npc:
            let body = SKShapeNode(ellipseOf: CGSize(width: 22, height: 34))
            body.fillColor = npcColor(for: grid)
            body.strokeColor = .clear
            body.position = CGPoint(x: 0, y: 25)
            let head = SKShapeNode(circleOfRadius: 9)
            head.fillColor = UIColor(red: 0.88, green: 0.70, blue: 0.48, alpha: 1)
            head.strokeColor = .clear
            head.position = CGPoint(x: 0, y: 49)
            container.addChild(body)
            container.addChild(head)
            reactiveNodes.append(container)
            container.run(.repeatForever(.sequence([
                .moveBy(x: 0, y: 4, duration: 0.45),
                .moveBy(x: 0, y: -4, duration: 0.45)
            ])))
        case .sign:
            let post = SKShapeNode(rectOf: CGSize(width: 7, height: 35), cornerRadius: 2)
            post.fillColor = UIColor(red: 0.38, green: 0.25, blue: 0.15, alpha: 1)
            post.strokeColor = .clear
            post.position = CGPoint(x: 0, y: 18)
            let face = SKShapeNode(rectOf: CGSize(width: 58, height: 24), cornerRadius: 3)
            face.fillColor = UIColor(red: 0.82, green: 0.62, blue: 0.30, alpha: 1)
            face.strokeColor = UIColor(red: 0.30, green: 0.20, blue: 0.12, alpha: 1)
            face.position = CGPoint(x: 0, y: 44)
            container.addChild(post)
            container.addChild(face)
        }

        worldNode.addChild(container)
    }

    private func buildGroucho() {
        avatarNode.removeAllChildren()
        let body = SKShapeNode(ellipseOf: CGSize(width: 48, height: 26))
        body.fillColor = UIColor(red: 0.73, green: 0.42, blue: 0.20, alpha: 1)
        body.strokeColor = .clear
        body.position = CGPoint(x: 0, y: 20)

        let head = SKShapeNode(circleOfRadius: 16)
        head.fillColor = UIColor(red: 0.82, green: 0.52, blue: 0.28, alpha: 1)
        head.strokeColor = .clear
        head.position = CGPoint(x: 24, y: 28)

        let ear = SKShapeNode(ellipseOf: CGSize(width: 10, height: 24))
        ear.fillColor = UIColor(red: 0.36, green: 0.20, blue: 0.12, alpha: 1)
        ear.strokeColor = .clear
        ear.position = CGPoint(x: 17, y: 30)
        ear.zRotation = 0.35

        let tail = SKShapeNode(rectOf: CGSize(width: 24, height: 6), cornerRadius: 3)
        tail.fillColor = UIColor(red: 0.73, green: 0.42, blue: 0.20, alpha: 1)
        tail.strokeColor = .clear
        tail.position = CGPoint(x: -30, y: 27)
        tail.zRotation = 0.35

        let eye = SKShapeNode(circleOfRadius: 2.5)
        eye.fillColor = .black
        eye.strokeColor = .clear
        eye.position = CGPoint(x: 30, y: 32)

        avatarNode.addChild(tail)
        avatarNode.addChild(body)
        avatarNode.addChild(head)
        avatarNode.addChild(ear)
        avatarNode.addChild(eye)
        worldNode.addChild(avatarNode)
        updateGrouchoPosition()
    }

    private func buildPatch() {
        patchNode.removeAllChildren()
        let glow = SKShapeNode(circleOfRadius: 28)
        glow.fillColor = UIColor(red: 1.0, green: 0.78, blue: 0.24, alpha: 0.18)
        glow.strokeColor = .clear
        let patch = SKShapeNode(rectOf: CGSize(width: 30, height: 30), cornerRadius: 6)
        patch.fillColor = UIColor(red: 1.0, green: 0.78, blue: 0.24, alpha: 1)
        patch.strokeColor = UIColor(red: 0.45, green: 0.28, blue: 0.12, alpha: 1)
        patch.zRotation = .pi / 4
        patchNode.addChild(glow)
        patchNode.addChild(patch)
        patchNode.position = iso(x: patchGrid.x, y: patchGrid.y)
        patchNode.zPosition = 400 + patchGrid.x + patchGrid.y
        patchNode.isHidden = true
        patchNode.run(.repeatForever(.sequence([
            .scale(to: 1.1, duration: 0.35),
            .scale(to: 0.94, duration: 0.35)
        ])))
        worldNode.addChild(patchNode)
    }

    private func updateGrouchoPosition() {
        avatarNode.position = iso(x: grouchoGrid.x, y: grouchoGrid.y)
        avatarNode.zPosition = 500 + grouchoGrid.x + grouchoGrid.y
        avatarNode.setScale(1 + beatClock.energy * 0.03)
    }

    private func updatePatchState() {
        patchNode.alpha = 0.7 + beatClock.energy * 0.3
    }

    private func drawBarkPulse(onBeat: Bool) {
        let pulse = SKShapeNode(ellipseOf: CGSize(width: 56, height: 22))
        pulse.position = iso(x: grouchoGrid.x, y: grouchoGrid.y)
        pulse.strokeColor = onBeat
            ? UIColor(red: 1.0, green: 0.78, blue: 0.24, alpha: 0.9)
            : UIColor(red: 0.50, green: 0.65, blue: 0.80, alpha: 0.55)
        pulse.lineWidth = onBeat ? 5 : 3
        pulse.fillColor = .clear
        pulse.zPosition = 800
        pulseNode.addChild(pulse)
        pulse.run(.sequence([
            .group([
                .scale(to: onBeat ? 5.2 : 3.2, duration: 0.55),
                .fadeOut(withDuration: 0.55)
            ]),
            .removeFromParent()
        ]))
    }

    private func nudgeWorld(onBeat: Bool) {
        let scale: CGFloat = onBeat ? 1.18 : 1.06
        let duration: TimeInterval = onBeat ? 0.12 : 0.2
        for node in reactiveNodes {
            node.run(.sequence([
                .scale(to: scale, duration: duration),
                .scale(to: 1, duration: duration)
            ]))
        }
    }

    private func refreshStageTiles() {
        let fill = color(for: .stage)
        for node in stageTileNodes {
            node.fillColor = fill
            node.run(.sequence([
                .scale(to: stageLit ? 1.08 : 1, duration: 0.12),
                .scale(to: 1, duration: 0.18)
            ]))
        }
    }

    private func runCompletionBurst() {
        for index in 0..<12 {
            let sparkle = SKShapeNode(circleOfRadius: 4)
            sparkle.fillColor = UIColor(red: 1.0, green: 0.82, blue: 0.32, alpha: 1)
            sparkle.strokeColor = .clear
            sparkle.position = iso(x: grouchoGrid.x, y: grouchoGrid.y)
            sparkle.zPosition = 900
            pulseNode.addChild(sparkle)
            let angle = CGFloat(index) / 12 * .pi * 2
            sparkle.run(.sequence([
                .group([
                    .moveBy(x: cos(angle) * 120, y: sin(angle) * 70, duration: 0.65),
                    .fadeOut(withDuration: 0.65)
                ]),
                .removeFromParent()
            ]))
        }
    }

    private func updateCameraLayout() {
        let fitScale = min(size.width / 860, size.height / 760)
        let worldScale = max(0.42, min(0.92, fitScale))
        worldNode.setScale(worldScale)
        pulseNode.setScale(worldScale)
        worldNode.position = CGPoint(x: size.width / 2, y: size.height * 0.28)
        pulseNode.position = worldNode.position
    }

    private func iso(x: CGFloat, y: CGFloat) -> CGPoint {
        CGPoint(
            x: (x - y) * Self.tileWidth * 0.5,
            y: (CGFloat(Self.mapHeight) - (x + y)) * Self.tileHeight * 0.5
        )
    }

    private func tileType(x: Int, y: Int) -> FrattypipelineTile {
        if x >= 8 && y >= 6 { return .water }
        if (x >= 4 && x <= 8 && y >= 3 && y <= 6) || (x == 3 && y >= 5) { return .path }
        if x >= 5 && x <= 7 && y >= 3 && y <= 4 { return .stage }
        return .grass
    }

    private func color(for tile: FrattypipelineTile) -> UIColor {
        switch tile {
        case .grass:
            return UIColor(red: 0.36, green: 0.58, blue: 0.34, alpha: 1)
        case .path:
            return UIColor(red: 0.48, green: 0.36, blue: 0.24, alpha: 1)
        case .stage:
            return stageLit
                ? UIColor(red: 0.72, green: 0.52, blue: 0.28, alpha: 1)
                : UIColor(red: 0.42, green: 0.32, blue: 0.24, alpha: 1)
        case .water:
            return UIColor(red: 0.28, green: 0.53, blue: 0.58, alpha: 1)
        }
    }

    private func npcColor(for grid: CGPoint) -> UIColor {
        let index = Int((grid.x * 10 + grid.y * 17).rounded()) % 3
        switch index {
        case 0:
            return .systemPink
        case 1:
            return .systemYellow
        default:
            return .systemTeal
        }
    }

    private func diamondNode(fill: UIColor, stroke: UIColor) -> SKShapeNode {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: Self.tileHeight / 2))
        path.addLine(to: CGPoint(x: Self.tileWidth / 2, y: 0))
        path.addLine(to: CGPoint(x: 0, y: -Self.tileHeight / 2))
        path.addLine(to: CGPoint(x: -Self.tileWidth / 2, y: 0))
        path.closeSubpath()

        let node = SKShapeNode(path: path)
        node.fillColor = fill
        node.strokeColor = stroke
        node.lineWidth = 1
        return node
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }
}
