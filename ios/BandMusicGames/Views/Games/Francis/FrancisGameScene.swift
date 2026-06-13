import SpriteKit
import Combine
import CoreMotion

enum FrancisPhase {
    case pressPlay
    case intro
    case playing
    case ended
}

@MainActor
final class FrancisGameScene: SKScene, ObservableObject {
    @Published private(set) var phase: FrancisPhase = .pressPlay
    private(set) var levelNum: Int = 1
    var config: FrancisLevelConfig { FrancisLevels.all[levelNum - 1] }

    // MARK: - Constants
    private let ambientCount = 75
    private var trackDuration: TimeInterval { config.timeLimit }

    // MARK: - Nodes
    private let worldNode = SKNode()
    private let ambientLayer = SKNode()
    private let linksLayer = SKNode()
    private let targetsLayer = SKNode()
    private var dragLine: SKShapeNode?

    private var hud: FrancisHUDNode?
    private var resultCard: FrancisResultCardNode?

    // MARK: - Motion
    private let motion = CMMotionManager()
    private var tiltX: CGFloat = 0
    private var tiltY: CGFloat = 0

    // MARK: - Game State
    private var links: [(Int, Int)] = []
    private var dragStartStar: Int?
    private var startTime: Date?
    private var elapsedTime: TimeInterval = 0
    private var isPreviewActive = false

    var correctCount: Int {
        links.filter { link in
            config.edges.contains { ($0.0 == link.0 && $0.1 == link.1) || ($0.0 == link.1 && $0.1 == link.0) }
        }.count
    }

    var onDismiss: (() -> Void)?

    // MARK: - Construction
    static func make() -> FrancisGameScene {
        let scene = FrancisGameScene(size: CGSize(width: 750, height: 1334))
        scene.scaleMode = .aspectFill
        scene.backgroundColor = SKColor(red: 0.02, green: 0.03, blue: 0.06, alpha: 1)
        return scene
    }

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        if worldNode.parent == nil {
            addChild(worldNode)
            worldNode.addChild(ambientLayer)
            worldNode.addChild(linksLayer)
            worldNode.addChild(targetsLayer)
        }

        if hud == nil {
            let hudNode = FrancisHUDNode(size: size)
            hudNode.zPosition = 50
            addChild(hudNode)
            hud = hudNode
        }

        setupMotion()
    }

    // MARK: - Lifecycle
    func startIntro() {
        phase = .intro
    }

    func startLevel(_ n: Int) {
        levelNum = max(1, min(n, FrancisLevels.all.count))
        phase = .playing
        startTime = nil
        elapsedTime = 0
        isPreviewActive = true
        linksLayer.removeAllActions()
        resetLevel()
        showConstellationPreview()
    }

    private func showConstellationPreview() {
        hud?.update(level: config, correct: 0, total: config.edges.count, timeRemaining: trackDuration, progress: 0)
        for (a, b) in config.edges {
            let start = config.stars[a]
            let end = config.stars[b]
            let path = CGMutablePath()
            path.move(to: CGPoint(x: start.nx * size.width, y: (1.0 - start.ny) * size.height))
            path.addLine(to: CGPoint(x: end.nx * size.width, y: (1.0 - end.ny) * size.height))
            let node = SKShapeNode(path: path)
            node.strokeColor = SKColor(red: 0.55, green: 0.80, blue: 1.0, alpha: 0.9)
            node.lineWidth = 2.5
            node.name = "preview_line"
            linksLayer.addChild(node)
        }
        linksLayer.run(SKAction.sequence([
            SKAction.wait(forDuration: 1.6),
            SKAction.fadeOut(withDuration: 0.4),
            SKAction.run { [weak self] in
                guard let self else { return }
                self.linksLayer.removeAllChildren()
                self.linksLayer.alpha = 1
                self.isPreviewActive = false
                self.startTime = Date()
            },
        ]))
    }

    private func resetLevel() {
        links.removeAll()
        linksLayer.removeAllChildren()
        targetsLayer.removeAllChildren()
        ambientLayer.removeAllChildren()
        resultCard?.removeFromParent()
        resultCard = nil

        setupAmbientStars()
        setupTargetStars()
    }

    // MARK: - Setup
    private func setupAmbientStars() {
        for i in 0..<ambientCount {
            let nx = AmbientStar.pseudo(i * 2 + 1)
            let ny = AmbientStar.pseudo(i * 2 + 2)
            let r = 0.6 + AmbientStar.pseudo(i * 3) * 1.4

            let node = SKShapeNode(circleOfRadius: r)
            node.fillColor = .white.withAlphaComponent(0.55)
            node.strokeColor = .clear
            node.position = CGPoint(x: nx * size.width, y: (1.0 - ny) * size.height)
            ambientLayer.addChild(node)
        }
    }

    private func setupTargetStars() {
        for (index, star) in config.stars.enumerated() {
            let node = createStarNode(isActive: false)
            node.position = CGPoint(x: star.nx * size.width, y: (1.0 - star.ny) * size.height)
            node.name = "star_\(index)"
            targetsLayer.addChild(node)
        }
    }

    private func createStarNode(isActive: Bool) -> SKNode {
        let starNode = SKNode()
        let r: CGFloat = isActive ? 8 : 4

        let glow = SKShapeNode(circleOfRadius: r * 3)
        glow.fillColor = SKColor(red: 1.0, green: 0.82, blue: 0.48, alpha: 0.25)
        glow.strokeColor = .clear
        starNode.addChild(glow)

        let core = SKShapeNode(circleOfRadius: r)
        core.fillColor = SKColor(red: 1.0, green: 0.82, blue: 0.48, alpha: 1.0)
        core.strokeColor = .clear
        starNode.addChild(core)

        return starNode
    }

    // MARK: - Input
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }

        if phase == .playing, !isPreviewActive {
            let location = touch.location(in: targetsLayer)
            if let starIndex = findNearestStar(to: location) {
                dragStartStar = starIndex
                createDragLine(from: location)
            }
        } else if phase == .ended {
            _ = resultCard?.handleTouch(touch, in: self)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard phase == .playing, let touch = touches.first, let _ = dragStartStar else { return }
        let location = touch.location(in: targetsLayer)
        updateDragLine(to: location)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard phase == .playing, let touch = touches.first, let startIdx = dragStartStar else { return }
        let location = touch.location(in: targetsLayer)

        if let endIdx = findNearestStar(to: location), startIdx != endIdx {
            tryConnect(startIdx, endIdx)
            clearDragLine()
        } else {
            fadeDragLine()
        }
        dragStartStar = nil
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        fadeDragLine()
        dragStartStar = nil
    }

    private func findNearestStar(to point: CGPoint) -> Int? {
        for (index, star) in config.stars.enumerated() {
            let starPos = CGPoint(x: star.nx * size.width, y: (1.0 - star.ny) * size.height)
            if hypot(starPos.x - point.x, starPos.y - point.y) < 50 {
                return index
            }
        }
        return nil
    }

    private func tryConnect(_ a: Int, _ b: Int) {
        let link = (min(a, b), max(a, b))
        if !links.contains(where: { $0 == link }) {
            links.append(link)
            renderLink(a: a, b: b)

            if correctCount == config.edges.count {
                endLevel()
            }
        }
    }

    private func renderLink(a: Int, b: Int) {
        let start = config.stars[a]
        let end = config.stars[b]

        let path = CGMutablePath()
        path.move(to: CGPoint(x: start.nx * size.width, y: (1.0 - start.ny) * size.height))
        path.addLine(to: CGPoint(x: end.nx * size.width, y: (1.0 - end.ny) * size.height))

        let node = SKShapeNode(path: path)
        let isCorrect = config.edges.contains { ($0.0 == a && $0.1 == b) || ($0.0 == b && $0.1 == a) }
        node.strokeColor = isCorrect
            ? SKColor(red: 0.65, green: 0.94, blue: 0.65, alpha: 0.85)
            : SKColor(red: 1.0, green: 0.5, blue: 0.4, alpha: 0.6)
        node.lineWidth = 2
        linksLayer.addChild(node)

        if isCorrect {
            HapticManager.impact(.soft)
            for idx in [a, b] {
                if let starNode = targetsLayer.childNode(withName: "star_\(idx)") {
                    starNode.removeAction(forKey: "starPop")
                    starNode.run(.sequence([
                        .scale(to: 1.5, duration: 0.07),
                        .scale(to: 1.0, duration: 0.12),
                    ]), withKey: "starPop")
                }
            }
        } else {
            HapticManager.impact(.rigid)
        }

        if !isCorrect {
            let key = (min(a, b), max(a, b))
            let nudge: CGFloat = 3
            node.run(SKAction.sequence([
                SKAction.moveBy(x: -nudge, y: 0, duration: 0.05),
                SKAction.moveBy(x: nudge * 2, y: 0, duration: 0.06),
                SKAction.moveBy(x: -nudge, y: 0, duration: 0.05),
                SKAction.wait(forDuration: 1.0),
                SKAction.fadeOut(withDuration: 0.4),
                SKAction.removeFromParent(),
            ]))
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.65) { [weak self] in
                self?.links.removeAll { $0 == key }
            }
        }
    }

    private func endLevel() {
        phase = .ended
        let won = correctCount == config.edges.count
        HapticManager.notification(won ? .success : .error)

        let isLast = levelNum == FrancisLevels.all.count
        let card = FrancisResultCardNode(
            size: size,
            config: config,
            correct: correctCount,
            total: config.edges.count,
            isLast: isLast,
            onNext: { [weak self] in guard let self else { return }; self.startLevel(self.levelNum + 1) },
            onFinish: { [weak self] in self?.onDismiss?() }
        )
        card.position = CGPoint(x: size.width / 2, y: size.height / 2)
        card.alpha = 0
        card.setScale(0.88)
        addChild(card)
        resultCard = card
        card.run(SKAction.group([
            SKAction.fadeIn(withDuration: 0.3),
            SKAction.scale(to: 1.0, duration: 0.3),
        ]))
    }

    private func createDragLine(from: CGPoint) {
        let path = CGMutablePath()
        path.move(to: from)
        path.addLine(to: from)

        let node = SKShapeNode(path: path)
        node.strokeColor = SKColor(red: 0.96, green: 0.7, blue: 0.38, alpha: 0.75)
        node.lineWidth = 2
        node.glowWidth = 5
        node.lineCap = .round
        targetsLayer.addChild(node)
        dragLine = node
    }

    private func updateDragLine(to point: CGPoint) {
        guard let dragLine = dragLine, let startIdx = dragStartStar else { return }
        let start = config.stars[startIdx]
        let path = CGMutablePath()
        path.move(to: CGPoint(x: start.nx * size.width, y: (1.0 - start.ny) * size.height))
        path.addLine(to: point)
        dragLine.path = path
    }

    private func clearDragLine() {
        dragLine?.removeFromParent()
        dragLine = nil
    }

    private func fadeDragLine() {
        guard let line = dragLine else { return }
        dragLine = nil
        line.run(.sequence([
            .fadeOut(withDuration: 0.18),
            .removeFromParent(),
        ]))
    }

    // MARK: - Updates
    override func update(_ currentTime: TimeInterval) {
        updateMotion()

        if phase == .playing, let start = startTime, !isPreviewActive {
            elapsedTime = -start.timeIntervalSinceNow
            let remaining = max(0, trackDuration - elapsedTime)
            hud?.update(
                level: config,
                correct: correctCount,
                total: config.edges.count,
                timeRemaining: remaining,
                progress: elapsedTime / trackDuration
            )

            if remaining <= 0 {
                endLevel()
            }
        }

        hud?.isHidden = (phase == .pressPlay || phase == .intro)
    }

    private func setupMotion() {
        guard motion.isDeviceMotionAvailable else { return }
        motion.deviceMotionUpdateInterval = 1.0 / 60
        motion.startDeviceMotionUpdates()
    }

    private func updateMotion() {
        guard let data = motion.deviceMotion else { return }
        let targetX = CGFloat(data.attitude.roll * 15)
        let targetY = CGFloat((data.attitude.pitch - .pi / 2) * 10)

        tiltX += (targetX - tiltX) * 0.1
        tiltY += (targetY - tiltY) * 0.1

        worldNode.position = CGPoint(x: tiltX, y: tiltY)
    }
}

// MARK: - Ambient Star Helper
private struct AmbientStar {
    static func pseudo(_ n: Int) -> Double {
        let x = sin(Double(n) * 9301 + 49297) * 233280
        return x - floor(x)
    }
}
