import SpriteKit

@MainActor
final class BallNode: SKNode {
    private let ballRadius: CGFloat = 13
    private let coreNode = SKShapeNode()
    
    var isMade: Bool = false
    var shotTeam: HalfCourtTeam = .home
    var shooterID: HalfCourtHeroID?

    override init() {
        super.init()
        setup()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        // Visuals
        let circle = SKShapeNode(circleOfRadius: ballRadius)
        circle.fillColor = SKColor(red: 0.85, green: 0.42, blue: 0.11, alpha: 1.0) // D96A1B
        circle.strokeColor = SKColor(red: 0.48, green: 0.16, blue: 0.05, alpha: 1.0) // 7A2A0C
        circle.lineWidth = 1.5
        addChild(circle)
        
        // Seams
        let hLine = SKShapeNode(rectOf: CGSize(width: ballRadius * 2, height: 1))
        hLine.fillColor = SKColor(red: 0.48, green: 0.16, blue: 0.05, alpha: 0.75)
        hLine.strokeColor = .clear
        addChild(hLine)
        
        let vLine = SKShapeNode(rectOf: CGSize(width: 1, height: ballRadius * 2))
        vLine.fillColor = SKColor(red: 0.48, green: 0.16, blue: 0.05, alpha: 0.75)
        vLine.strokeColor = .clear
        addChild(vLine)
        
        // Physics
        let body = SKPhysicsBody(circleOfRadius: ballRadius)
        body.categoryBitMask = HalfCourtPhysicsCategory.ball
        body.collisionBitMask = HalfCourtPhysicsCategory.court | HalfCourtPhysicsCategory.rim
        body.contactTestBitMask = HalfCourtPhysicsCategory.rim | HalfCourtPhysicsCategory.net
        body.restitution = 0.65
        body.friction = 0.2
        body.linearDamping = 0.1
        body.mass = 0.5
        self.physicsBody = body
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
