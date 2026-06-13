import SpriteKit

@MainActor
final class FrancisHUDNode: SKNode {
    private let titleLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let artistLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
    private let matchLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let timeLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let progressBar = SKShapeNode(rectOf: CGSize(width: 200, height: 4), cornerRadius: 2)
    private let progressFill = SKShapeNode(rectOf: CGSize(width: 0, height: 4), cornerRadius: 2)

    private var size: CGSize = .zero

    init(size: CGSize) {
        self.size = size
        super.init()
        setup()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        let padding: CGFloat = 24
        let topY = size.height - padding - 40

        // Title
        titleLabel.fontSize = 18
        titleLabel.horizontalAlignmentMode = .left
        titleLabel.fontColor = .white
        titleLabel.position = CGPoint(x: padding, y: topY)
        addChild(titleLabel)

        // Artist
        artistLabel.fontSize = 12
        artistLabel.horizontalAlignmentMode = .left
        artistLabel.fontColor = SKColor(red: 0.43, green: 0.48, blue: 0.58, alpha: 1)
        artistLabel.position = CGPoint(x: padding, y: topY - 20)
        addChild(artistLabel)

        // Match Count
        matchLabel.fontSize = 16
        matchLabel.horizontalAlignmentMode = .right
        matchLabel.fontColor = .white
        matchLabel.position = CGPoint(x: size.width - padding, y: topY)
        addChild(matchLabel)

        // Time Label
        timeLabel.fontSize = 14
        timeLabel.horizontalAlignmentMode = .right
        timeLabel.fontColor = SKColor(red: 1.0, green: 0.82, blue: 0.48, alpha: 1)
        timeLabel.position = CGPoint(x: size.width - padding, y: topY - 20)
        addChild(timeLabel)

        // Progress Bar
        let barWidth = size.width - (padding * 2)
        progressBar.path = CGPath(roundedRect: CGRect(x: 0, y: 0, width: barWidth, height: 4), cornerWidth: 2, cornerHeight: 2, transform: nil)
        progressBar.fillColor = .white.withAlphaComponent(0.1)
        progressBar.strokeColor = .clear
        progressBar.position = CGPoint(x: padding, y: topY - 40)
        addChild(progressBar)

        progressFill.fillColor = SKColor(red: 1.0, green: 0.82, blue: 0.48, alpha: 1.0)
        progressFill.strokeColor = .clear
        progressFill.position = CGPoint(x: padding, y: topY - 40)
        addChild(progressFill)
    }

    func update(level: FrancisLevelConfig, correct: Int, total: Int, timeRemaining: TimeInterval, progress: Double) {
        titleLabel.text = level.constellationName
        artistLabel.text = level.subtitle
        matchLabel.text = "\(correct) / \(total)"

        let seconds = Int(timeRemaining)
        timeLabel.text = "\(seconds / 60):\(String(format: "%02d", seconds % 60)) left"
        if timeRemaining < 30 {
            timeLabel.fontColor = SKColor(red: 1.0, green: 0.5, blue: 0.4, alpha: 1)
        }

        let barWidth = size.width - 48
        progressFill.path = CGPath(roundedRect: CGRect(x: 0, y: 0, width: barWidth * CGFloat(progress), height: 4), cornerWidth: 2, cornerHeight: 2, transform: nil)
    }
}
