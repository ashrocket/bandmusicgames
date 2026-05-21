import SpriteKit

@MainActor
final class HalfCourtHUDNode: SKNode {
    private let homeScoreLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let awayScoreLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let seriesLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
    private let shotClockLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    
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
        let padding: CGFloat = 40
        let topY = size.height - padding - 60
        
        homeScoreLabel.fontSize = 42
        homeScoreLabel.fontColor = SKColor(red: 1.0, green: 0.08, blue: 0.58, alpha: 1.0) // FF1493
        homeScoreLabel.position = CGPoint(x: size.width / 2 - 80, y: topY)
        addChild(homeScoreLabel)
        
        let dash = SKLabelNode(text: "-")
        dash.fontSize = 30
        dash.fontColor = .white.withAlphaComponent(0.5)
        dash.position = CGPoint(x: size.width / 2, y: topY + 8)
        addChild(dash)
        
        awayScoreLabel.fontSize = 42
        awayScoreLabel.fontColor = SKColor(red: 1.0, green: 0.42, blue: 0.21, alpha: 1.0) // FF6B35
        awayScoreLabel.position = CGPoint(x: size.width / 2 + 80, y: topY)
        addChild(awayScoreLabel)
        
        seriesLabel.fontSize = 14
        seriesLabel.fontColor = .white.withAlphaComponent(0.7)
        seriesLabel.position = CGPoint(x: size.width / 2, y: topY - 40)
        addChild(seriesLabel)
        
        shotClockLabel.fontSize = 18
        shotClockLabel.fontColor = .yellow
        shotClockLabel.position = CGPoint(x: size.width - 60, y: topY + 10)
        addChild(shotClockLabel)
    }
    
    func update(homeScore: Int, awayScore: Int, homeWins: Int, awayWins: Int, shotClock: Int) {
        homeScoreLabel.text = "\(homeScore)"
        awayScoreLabel.text = "\(awayScore)"
        seriesLabel.text = "SERIES: \(homeWins) - \(awayWins)"
        shotClockLabel.text = "\(shotClock)s"
        
        if shotClock <= 3 {
            shotClockLabel.fontColor = .red
        } else {
            shotClockLabel.fontColor = .yellow
        }
    }
}
