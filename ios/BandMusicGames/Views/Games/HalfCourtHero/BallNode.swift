import SpriteKit

@MainActor
final class BallNode: SKNode {
    /// Physics radius — rim-bounce and scoring tuning depend on this; don't grow it for looks.
    let ballRadius: CGFloat = 11
    /// Drawn radius — larger than physics so the ball reads clearly on a phone screen.
    let visualRadius: CGFloat = 16
    private var spriteNode: SKSpriteNode?
    private var fireGlow: SKShapeNode?

    private(set) var isHeld = true
    var shotTeam: HalfCourtTeam = .home
    var shotPoints = 2
    var scoredThisFlight = false
    var missResolved = false

    override init() {
        super.init()
        setup()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        if installSpriteBody() {
            runSpinAnimation()
        } else {
            drawFallbackBody()
        }
    }

    /// Pins the ball to a carrier's hand — no physics while held.
    func hold() {
        isHeld = true
        physicsBody = nil
        zRotation = 0
        removeAction(forKey: "ball-roll")
    }

    /// Releases the ball into flight with an exact initial velocity.
    func launch(velocity: CGVector, team: HalfCourtTeam, points: Int) {
        isHeld = false
        shotTeam = team
        shotPoints = points
        scoredThisFlight = false
        missResolved = false

        let body = SKPhysicsBody(circleOfRadius: ballRadius)
        body.categoryBitMask = HalfCourtPhysicsCategory.ball
        body.collisionBitMask = HalfCourtPhysicsCategory.court | HalfCourtPhysicsCategory.rim
        body.contactTestBitMask = HalfCourtPhysicsCategory.rim
            | HalfCourtPhysicsCategory.net
            | HalfCourtPhysicsCategory.court
        body.restitution = 0.62
        body.friction = 0.3
        body.linearDamping = 0.06
        body.angularDamping = 0.7
        body.mass = 0.5
        body.velocity = velocity
        body.angularVelocity = velocity.dx >= 0 ? -7 : 7
        physicsBody = body
    }

    func setOnFire(_ on: Bool) {
        if on {
            guard fireGlow == nil else { return }
            let glow = SKShapeNode(circleOfRadius: visualRadius + 7)
            glow.fillColor = SKColor(red: 1.0, green: 0.45, blue: 0.1, alpha: 0.4)
            glow.strokeColor = SKColor(red: 1.0, green: 0.72, blue: 0.15, alpha: 0.75)
            glow.lineWidth = 2
            glow.zPosition = -1
            let pulse = SKAction.sequence([
                SKAction.group([SKAction.scale(to: 1.25, duration: 0.18), SKAction.fadeAlpha(to: 0.55, duration: 0.18)]),
                SKAction.group([SKAction.scale(to: 0.92, duration: 0.18), SKAction.fadeAlpha(to: 0.95, duration: 0.18)]),
            ])
            glow.run(SKAction.repeatForever(pulse))
            insertChild(glow, at: 0)
            fireGlow = glow
            spriteNode?.color = SKColor(red: 1.0, green: 0.5, blue: 0.1, alpha: 1)
            spriteNode?.colorBlendFactor = 0.3
        } else {
            fireGlow?.removeFromParent()
            fireGlow = nil
            spriteNode?.colorBlendFactor = 0
        }
    }

    private func installSpriteBody() -> Bool {
        guard let firstTexture = HalfCourtSpriteFactory.ballSpinTextures().first else { return false }

        let sprite = SKSpriteNode(texture: firstTexture)
        sprite.size = CGSize(width: visualRadius * 2.5, height: visualRadius * 2.5)
        sprite.name = "halfcourt-ball-sprite"
        addChild(sprite)
        spriteNode = sprite
        return true
    }

    private func runSpinAnimation() {
        guard let spriteNode, spriteNode.action(forKey: "ball-spin") == nil else { return }
        let textures = HalfCourtSpriteFactory.ballSpinTextures()
        guard !textures.isEmpty else { return }

        let animation = SKAction.animate(
            with: textures,
            timePerFrame: 1.0 / 16.0,
            resize: false,
            restore: false
        )
        spriteNode.run(SKAction.repeatForever(animation), withKey: "ball-spin")
    }

    private func drawFallbackBody() {
        let circle = SKShapeNode(circleOfRadius: visualRadius)
        circle.fillColor = SKColor(red: 0.85, green: 0.42, blue: 0.11, alpha: 1.0) // D96A1B
        circle.strokeColor = SKColor(red: 0.48, green: 0.16, blue: 0.05, alpha: 1.0) // 7A2A0C
        circle.lineWidth = 1.5
        addChild(circle)

        let hLine = SKShapeNode(rectOf: CGSize(width: visualRadius * 2, height: 1))
        hLine.fillColor = SKColor(red: 0.48, green: 0.16, blue: 0.05, alpha: 0.75)
        hLine.strokeColor = .clear
        addChild(hLine)

        let vLine = SKShapeNode(rectOf: CGSize(width: 1, height: visualRadius * 2))
        vLine.fillColor = SKColor(red: 0.48, green: 0.16, blue: 0.05, alpha: 0.75)
        vLine.strokeColor = .clear
        addChild(vLine)
    }
}

struct HalfCourtPhysicsCategory {
    static let none: UInt32 = 0
    static let ball: UInt32 = 0b1
    static let court: UInt32 = 0b10
    static let rim: UInt32 = 0b100
    static let net: UInt32 = 0b1000
    static let player: UInt32 = 0b10000
}
