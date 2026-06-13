import SpriteKit

@MainActor
final class HalfCourtResultCardNode: SKNode {
    private let bgNode = SKShapeNode(rectOf: CGSize(width: 400, height: 500), cornerRadius: 20)
    private let titleLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let scoreLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let seriesLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let actionButton = SKShapeNode(rectOf: CGSize(width: 240, height: 60), cornerRadius: 30)
    private let actionLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")

    private var onAction: (() -> Void)?

    init(homeScore: Int, awayScore: Int, homeWins: Int, awayWins: Int, isSeriesOver: Bool, onAction: @escaping () -> Void) {
        self.onAction = onAction
        super.init()
        setup(homeScore: homeScore, awayScore: awayScore, homeWins: homeWins, awayWins: awayWins, isSeriesOver: isSeriesOver)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup(homeScore: Int, awayScore: Int, homeWins: Int, awayWins: Int, isSeriesOver: Bool) {
        zPosition = 1000
        
        // Background
        bgNode.fillColor = SKColor(red: 0.1, green: 0.04, blue: 0.24, alpha: 0.95)
        bgNode.strokeColor = .yellow.withAlphaComponent(0.5)
        bgNode.lineWidth = 2
        addChild(bgNode)
        
        // Title
        let gameWon = homeScore > awayScore
        let seriesWon = homeWins >= 3
        if isSeriesOver {
            titleLabel.text = seriesWon ? "SERIES CHAMPIONS!" : "SERIES LOST"
            titleLabel.fontColor = seriesWon
                ? SKColor(red: 1, green: 0.84, blue: 0, alpha: 1)
                : SKColor(red: 1, green: 0.35, blue: 0.3, alpha: 1)
        } else {
            titleLabel.text = gameWon ? "GAME WON!" : "GAME LOST"
            titleLabel.fontColor = gameWon
                ? SKColor(red: 0.4, green: 0.95, blue: 0.5, alpha: 1)
                : SKColor(red: 1, green: 0.42, blue: 0.21, alpha: 1)
        }
        titleLabel.fontSize = 32
        titleLabel.position = CGPoint(x: 0, y: 180)
        addChild(titleLabel)
        
        // Game score
        scoreLabel.text = "YOU \(homeScore) – \(awayScore) CPU"
        scoreLabel.fontSize = 22
        scoreLabel.fontColor = .white.withAlphaComponent(0.85)
        scoreLabel.position = CGPoint(x: 0, y: 130)
        addChild(scoreLabel)

        // Series Score
        seriesLabel.text = "SERIES: \(homeWins)–\(awayWins)"
        seriesLabel.fontSize = 18
        seriesLabel.fontColor = .white.withAlphaComponent(0.65)
        seriesLabel.position = CGPoint(x: 0, y: 100)
        addChild(seriesLabel)

        // Details
        let sub = SKLabelNode(text: isSeriesOver ? "Best of 5 Complete" : "Next game →")
        sub.fontSize = 14
        sub.fontColor = .white.withAlphaComponent(0.5)
        sub.position = CGPoint(x: 0, y: 70)
        addChild(sub)
        
        // Action Button
        actionButton.fillColor = .yellow
        actionButton.strokeColor = .clear
        actionButton.position = CGPoint(x: 0, y: -180)
        actionButton.name = "action_btn"
        addChild(actionButton)
        
        actionLabel.text = isSeriesOver ? "BACK TO LOBBY" : "START NEXT GAME"
        actionLabel.fontSize = 18
        actionLabel.fontColor = .black
        actionLabel.position = CGPoint(x: 0, y: -186)
        actionLabel.verticalAlignmentMode = .center
        actionLabel.name = "action_btn"
        addChild(actionLabel)
    }

    func handleTouch(_ touch: UITouch) -> Bool {
        let location = touch.location(in: self)
        let node = atPoint(location)
        if node.name == "action_btn" {
            onAction?()
            return true
        }
        return false
    }
}
