import SpriteKit

@MainActor
final class FrancisResultCardNode: SKNode {
    private let bgNode = SKShapeNode(rectOf: CGSize(width: 340, height: 480), cornerRadius: 14)
    private let titleLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let subtitleLabel = SKLabelNode(fontNamed: "AvenirNext-Italic")
    private let scoreLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
    private let loreLabel = SKLabelNode(fontNamed: "AvenirNext-Regular")
    private let actionButton = SKShapeNode(rectOf: CGSize(width: 200, height: 44), cornerRadius: 22)
    private let actionLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let retryButton = SKShapeNode(rectOf: CGSize(width: 200, height: 44), cornerRadius: 22)
    private let retryLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")

    private var onNext: (() -> Void)?
    private var onFinish: (() -> Void)?
    private var onRetry: (() -> Void)?
    private var isLast: Bool = false

    init(size: CGSize, config: FrancisLevelConfig, correct: Int, total: Int, isLast: Bool, onNext: @escaping () -> Void, onFinish: @escaping () -> Void, onRetry: @escaping () -> Void) {
        self.onNext = onNext
        self.onFinish = onFinish
        self.onRetry = onRetry
        self.isLast = isLast
        super.init()
        setup(config: config, correct: correct, total: total, isLast: isLast)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setup(config: FrancisLevelConfig, correct: Int, total: Int, isLast: Bool) {
        zPosition = 100
        let won = correct == total

        bgNode.fillColor = SKColor(red: 0.09, green: 0.12, blue: 0.23, alpha: 0.95)
        bgNode.strokeColor = won
            ? SKColor(red: 1.0, green: 0.82, blue: 0.48, alpha: 0.35)
            : SKColor(red: 1.0, green: 0.42, blue: 0.21, alpha: 0.35)
        bgNode.lineWidth = 1
        addChild(bgNode)

        let resultLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        resultLabel.text = won ? "COMPLETE! ✓" : "TIME'S UP"
        resultLabel.fontSize = 14
        resultLabel.fontColor = won
            ? SKColor(red: 0.5, green: 0.95, blue: 0.55, alpha: 1)
            : SKColor(red: 1.0, green: 0.42, blue: 0.21, alpha: 1)
        resultLabel.position = CGPoint(x: -150, y: 205)
        resultLabel.horizontalAlignmentMode = .left
        addChild(resultLabel)

        titleLabel.text = config.constellationName
        titleLabel.fontSize = 28
        titleLabel.fontColor = SKColor(red: 1.0, green: 0.82, blue: 0.48, alpha: 1)
        titleLabel.position = CGPoint(x: -150, y: 175)
        titleLabel.horizontalAlignmentMode = .left
        addChild(titleLabel)

        subtitleLabel.text = config.subtitle
        subtitleLabel.fontSize = 14
        subtitleLabel.fontColor = SKColor(red: 0.43, green: 0.48, blue: 0.58, alpha: 1)
        subtitleLabel.position = CGPoint(x: -150, y: 153)
        subtitleLabel.horizontalAlignmentMode = .left
        addChild(subtitleLabel)

        scoreLabel.text = won ? "All \(total) lines matched!" : "You matched \(correct) of \(total) lines."
        scoreLabel.fontSize = 14
        scoreLabel.fontColor = .white
        scoreLabel.position = CGPoint(x: -150, y: 120)
        scoreLabel.horizontalAlignmentMode = .left
        addChild(scoreLabel)

        loreLabel.text = config.lore.replacingOccurrences(of: "**", with: "")
        loreLabel.fontSize = 12
        loreLabel.fontColor = .white.withAlphaComponent(0.75)
        loreLabel.position = CGPoint(x: -150, y: 80)
        loreLabel.horizontalAlignmentMode = .left
        loreLabel.verticalAlignmentMode = .top
        loreLabel.numberOfLines = 0
        loreLabel.preferredMaxLayoutWidth = 290
        addChild(loreLabel)

        if won {
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
        } else {
            // Primary: TRY AGAIN
            retryButton.fillColor = SKColor(red: 1.0, green: 0.82, blue: 0.48, alpha: 1)
            retryButton.strokeColor = .clear
            retryButton.position = CGPoint(x: 0, y: -155)
            retryButton.name = "retry_button"
            addChild(retryButton)

            retryLabel.text = "TRY AGAIN"
            retryLabel.fontSize = 12
            retryLabel.fontColor = SKColor(red: 0.1, green: 0.08, blue: 0.03, alpha: 1)
            retryLabel.position = CGPoint(x: 0, y: -159)
            retryLabel.verticalAlignmentMode = .center
            retryLabel.name = "retry_button"
            addChild(retryLabel)

            // Secondary: ghost skip button
            actionButton.fillColor = .clear
            actionButton.strokeColor = SKColor.white.withAlphaComponent(0.18)
            actionButton.lineWidth = 1
            actionButton.position = CGPoint(x: 0, y: -210)
            actionButton.name = "action_button"
            addChild(actionButton)

            actionLabel.text = isLast ? "BACK TO JUKEBOX" : "SKIP →"
            actionLabel.fontSize = 11
            actionLabel.fontColor = SKColor.white.withAlphaComponent(0.45)
            actionLabel.position = CGPoint(x: 0, y: -214)
            actionLabel.verticalAlignmentMode = .center
            actionLabel.name = "action_button"
            addChild(actionLabel)
        }
    }

    func handleTouch(_ touch: UITouch, in scene: SKScene) -> Bool {
        let location = touch.location(in: self)
        let node = atPoint(location)
        if node.name == "retry_button" {
            onRetry?()
            return true
        }
        if node.name == "action_button" {
            if isLast { onFinish?() } else { onNext?() }
            return true
        }
        return false
    }
}
