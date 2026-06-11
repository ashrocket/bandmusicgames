import SpriteKit

/// Pure mapping from the SHOOT charge value to a storm visual stage.
/// Window semantics must match HalfCourtHeroScene.shotError(): green and
/// perfect bounds are inclusive; past greenHigh the window is gone.
enum StormStage: Equatable {
    case clear
    case building(progress: CGFloat)   // 0...1 — how close the window is
    case green(perfect: Bool)
    case parted

    static func stage(charge: CGFloat?,
                      greenLow: CGFloat, greenHigh: CGFloat,
                      perfectLow: CGFloat, perfectHigh: CGFloat) -> StormStage {
        guard let c = charge else { return .clear }
        if c > greenHigh { return .parted }
        if c >= greenLow { return .green(perfect: c >= perfectLow && c <= perfectHigh) }
        return .building(progress: max(0, min(1, c / greenLow)))
    }

    /// Stage identity ignoring associated values — for one-shot transitions.
    var kind: Int {
        switch self {
        case .clear: return 0
        case .building: return 1
        case .green: return 2
        case .parted: return 3
        }
    }
}

/// Full-sky storm mirroring the SHOOT charge meter, so shot timing is readable
/// with a thumb covering the button: the sky darkens while charging, lightning
/// strikes and the sky turns green for the release window, and the clouds part
/// once the window has passed.
final class StormSkyNode: SKNode {
    private let sceneSize: CGSize
    private let greenLow: CGFloat
    private let greenHigh: CGFloat
    private let perfectLow: CGFloat
    private let perfectHigh: CGFloat

    private let leftCloud: SKSpriteNode
    private let rightCloud: SKSpriteNode
    private let greenWash: SKSpriteNode
    private var lastKind = StormStage.clear.kind

    private let maxDim: CGFloat = 0.5

    init(size: CGSize,
         greenLow: CGFloat, greenHigh: CGFloat,
         perfectLow: CGFloat, perfectHigh: CGFloat) {
        self.sceneSize = size
        self.greenLow = greenLow
        self.greenHigh = greenHigh
        self.perfectLow = perfectLow
        self.perfectHigh = perfectHigh

        let halfSize = CGSize(width: max(1, size.width / 2), height: max(1, size.height))
        let texture = Self.cloudGradientTexture(size: halfSize)
        leftCloud = SKSpriteNode(texture: texture, size: halfSize)
        rightCloud = SKSpriteNode(texture: texture, size: halfSize)
        greenWash = SKSpriteNode(
            color: SKColor(red: 0.2, green: 0.83, blue: 0.2, alpha: 1),
            size: CGSize(width: size.width, height: size.height * 0.7)
        )
        super.init()

        leftCloud.position = CGPoint(x: size.width * 0.25, y: size.height * 0.5)
        rightCloud.position = CGPoint(x: size.width * 0.75, y: size.height * 0.5)
        greenWash.position = CGPoint(x: size.width * 0.5, y: size.height * 0.65)
        greenWash.zPosition = 1
        leftCloud.alpha = 0
        rightCloud.alpha = 0
        greenWash.alpha = 0
        addChild(leftCloud)
        addChild(rightCloud)
        addChild(greenWash)
    }

    required init?(coder: NSCoder) { fatalError() }

    /// nil clears the sky; 0...1.18 drives the storm. Call every frame the
    /// charge changes, plus once with nil on release/cancel.
    func setCharge(_ charge: CGFloat?) {
        let stage = StormStage.stage(charge: charge,
                                     greenLow: greenLow, greenHigh: greenHigh,
                                     perfectLow: perfectLow, perfectHigh: perfectHigh)
        let entered = stage.kind != lastKind
        lastKind = stage.kind

        switch stage {
        case .clear:
            if entered { fadeOutAndRecenter() }
        case .building(let progress):
            if entered { resetForNewCharge() }
            let dim = maxDim * progress * progress   // eased — storm accelerates in
            leftCloud.alpha = dim
            rightCloud.alpha = dim
        case .green(let perfect):
            if entered {
                strikeLightning()
                HapticManager.impact(.heavy)   // thunder — feel the window open
            }
            leftCloud.alpha = maxDim
            rightCloud.alpha = maxDim
            greenWash.alpha = perfect ? 0.40 : 0.28
        case .parted:
            if entered { partClouds() }
        }
    }

    private func resetForNewCharge() {
        removeAllActions()
        for node in [leftCloud, rightCloud, greenWash] { node.removeAllActions() }
        leftCloud.position = CGPoint(x: sceneSize.width * 0.25, y: sceneSize.height * 0.5)
        rightCloud.position = CGPoint(x: sceneSize.width * 0.75, y: sceneSize.height * 0.5)
        leftCloud.alpha = 0
        rightCloud.alpha = 0
        greenWash.alpha = 0
    }

    private func fadeOutAndRecenter() {
        for node in [leftCloud, rightCloud, greenWash] {
            node.removeAllActions()
            node.run(.fadeOut(withDuration: 0.15))
        }
        // Slide the halves back once invisible so the next charge starts centered.
        removeAllActions()
        run(.sequence([
            .wait(forDuration: 0.16),
            .run { [weak self] in
                guard let self else { return }
                self.leftCloud.position = CGPoint(x: self.sceneSize.width * 0.25,
                                                  y: self.sceneSize.height * 0.5)
                self.rightCloud.position = CGPoint(x: self.sceneSize.width * 0.75,
                                                   y: self.sceneSize.height * 0.5)
            },
        ]))
    }

    private func partClouds() {
        greenWash.removeAllActions()
        greenWash.run(.fadeOut(withDuration: 0.12))
        let slide = sceneSize.width * 0.55
        for (cloud, dx) in [(leftCloud, -slide), (rightCloud, slide)] {
            cloud.removeAllActions()
            let move = SKAction.moveBy(x: dx, y: 0, duration: 0.25)
            move.timingMode = .easeIn
            cloud.run(.group([move, .fadeOut(withDuration: 0.25)]))
        }
    }

    private func strikeLightning() {
        let path = CGMutablePath()
        var point = CGPoint(
            x: CGFloat.random(in: sceneSize.width * 0.2...sceneSize.width * 0.8),
            y: sceneSize.height
        )
        path.move(to: point)
        let segments = 4
        let drop = (sceneSize.height * 0.45) / CGFloat(segments)
        for _ in 0..<segments {
            point = CGPoint(x: point.x + CGFloat.random(in: -34...34), y: point.y - drop)
            path.addLine(to: point)
        }
        let bolt = SKShapeNode(path: path)
        bolt.strokeColor = SKColor(red: 1, green: 1, blue: 0.85, alpha: 1)
        bolt.lineWidth = 3
        bolt.glowWidth = 9
        bolt.lineCap = .round
        bolt.zPosition = 2
        addChild(bolt)
        bolt.run(.sequence([
            .fadeAlpha(to: 0.6, duration: 0.05),
            .fadeAlpha(to: 1.0, duration: 0.04),
            .fadeOut(withDuration: 0.18),
            .removeFromParent(),
        ]))
    }

    private static func cloudGradientTexture(size: CGSize) -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let colors = [UIColor.black.cgColor,
                          UIColor.black.withAlphaComponent(0.35).cgColor]
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                            colors: colors as CFArray,
                                            locations: [0, 1]) else { return }
            // UIImage y=0 is the top; SKTexture maps image top to sprite top,
            // so this is darkest at the top of the sky.
            ctx.cgContext.drawLinearGradient(gradient,
                                             start: .zero,
                                             end: CGPoint(x: 0, y: size.height),
                                             options: [])
        }
        return SKTexture(image: image)
    }
}
