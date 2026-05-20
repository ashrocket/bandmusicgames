import SpriteKit

@MainActor
final class FrancisResultCardNode: SKNode {
    private let bgNode = SKShapeNode(rectOf: CGSize(width: 340, height: 480), cornerRadius: 14)
    private let titleLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let subtitleLabel = SKLabelNode(fontNamed: "AvenirNext-Italic")
    private let scoreLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
    private let loreLabel1 = SKLabelNode(fontNamed: "AvenirNext-Regular")
    private let loreLabel2 = SKLabelNode(fontNamed: "AvenirNext-Regular")
    private let actionButton = SKShapeNode(rectOf: CGSize(width: 200, height: 44), cornerRadius: 22)
    private let actionLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")

    private var onNext: (() -> Void)?
    private var onFinish: (() -> Void)?

    init(size: CGSize, config: FrancisLevelConfig, correct: Int, total: Int, isLast: Bool, onNext: @escaping () -> Void, onFinish: @escaping () -> Void) {
        self.onNext = onNext
        self.onFinish = onFinish
        super.init()
        setup(config: config, correct: correct, total: total, isLast: isLast)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup(config: FrancisLevelConfig, correct: Int, total: Int, isLast: Bool) {
        zPosition = 100

        // Background
        bgNode.fillColor = SKColor(red: 0.09, green: 0.12, blue: 0.23, alpha: 0.95)
        bgNode.strokeColor = SKColor(red: 1.0, green: 0.82, blue: 0.48, alpha: 0.3)
        bgNode.lineWidth = 1
        addChild(bgNode)

        // Title
        titleLabel.text = config.constellationName
        titleLabel.fontSize = 28
        titleLabel.fontColor = SKColor(red: 1.0, green: 0.82, blue: 0.48, alpha: 1)
        titleLabel.position = CGPoint(x: -150, y: 180)
        titleLabel.horizontalAlignmentMode = .left
        addChild(titleLabel)

        // Subtitle
        subtitleLabel.text = config.subtitle
        subtitleLabel.fontSize = 14
        subtitleLabel.fontColor = SKColor(red: 0.43, green: 0.48, blue: 0.58, alpha: 1)
        subtitleLabel.position = CGPoint(x: -150, y: 160)
        subtitleLabel.horizontalAlignmentMode = .left
        addChild(subtitleLabel)

        // Score
        scoreLabel.text = "You matched \(correct) of \(total) lines."
        scoreLabel.fontSize = 14
        scoreLabel.fontColor = .white
        scoreLabel.position = CGPoint(x: -150, y: 120)
        scoreLabel.horizontalAlignmentMode = .left
        addChild(scoreLabel)

        // Lore (Simplified for SpriteKit labels)
        loreLabel1.text = "One of the most recognizable patterns"
        loreLabel1.fontSize = 13
        loreLabel1.fontColor = .white.withAlphaComponent(0.85)
        loreLabel1.position = CGPoint(x: -150, y: 60)
        loreLabel1.horizontalAlignmentMode = .left
        addChild(loreLabel1)

        loreLabel2.text = "in the northern sky."
        loreLabel2.fontSize = 13
        loreLabel2.fontColor = .white.withAlphaComponent(0.85)
        loreLabel2.position = CGPoint(x: -150, y: 40)
        loreLabel2.horizontalAlignmentMode = .left
        addChild(loreLabel2)

        // Action Button
        actionButton.fillColor = SKColor(red: 1.0, green: 0.82, blue: 0.48, alpha: 1)
        actionButton.strokeColor = .clear
        actionButton.position = CGPoint(x: 0, y: -180)
        actionButton.name = "action_button"
        addChild(actionButton)

        actionLabel.text = isLast ? "BACK TO JUKEBOX" : "NEXT CONSTELLATION"
        actionLabel.fontSize = 12
        actionLabel.fontColor = SKColor(red: 0.1, green: 0.08, blue: 0.03, alpha: 1)
        actionLabel.position = CGPoint(x: 0, y: -184)
        actionLabel.verticalAlignmentMode = .center
        actionLabel.name = "action_button"
        addChild(actionLabel)
    }

    func handleTouch(_ touch: UITouch, in scene: SKScene) -> Bool {
        let location = touch.location(in: self)
        let node = atPoint(location)
        if node.name == "action_button" {
            onNext?() // Or onFinish depending on context, handled by caller
            return true
        }
        return false
    }
}
