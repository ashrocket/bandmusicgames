import SpriteKit

/// Slim top-edge HUD: scores flank a center dash, series pips + shot clock
/// tucked underneath, and an ON FIRE banner that appears while powered up.
/// Everything hugs the top so the court keeps the whole screen.
@MainActor
final class HalfCourtHUDNode: SKNode {
    private let backdrop = SKShapeNode()
    private let homeScoreLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let awayScoreLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let homeTagLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let awayTagLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let dashLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let seriesLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
    private let shotClockLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let fireBanner = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private var lastHomeScore = -1
    private var lastAwayScore = -1

    init(size: CGSize) {
        super.init()
        setup()
        layout(size: size)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        backdrop.fillColor = SKColor.black.withAlphaComponent(0.38)
        backdrop.strokeColor = SKColor.white.withAlphaComponent(0.08)
        backdrop.lineWidth = 1
        addChild(backdrop)

        homeScoreLabel.fontSize = 30
        homeScoreLabel.fontColor = SKColor(red: 1.0, green: 0.08, blue: 0.58, alpha: 1.0) // FF1493
        homeScoreLabel.horizontalAlignmentMode = .right
        addChild(homeScoreLabel)

        awayScoreLabel.fontSize = 30
        awayScoreLabel.fontColor = SKColor(red: 1.0, green: 0.42, blue: 0.21, alpha: 1.0) // FF6B35
        awayScoreLabel.horizontalAlignmentMode = .left
        addChild(awayScoreLabel)

        homeTagLabel.text = "YOU"
        homeTagLabel.fontSize = 9
        homeTagLabel.fontColor = .white.withAlphaComponent(0.55)
        homeTagLabel.horizontalAlignmentMode = .right
        addChild(homeTagLabel)

        awayTagLabel.text = "CPU"
        awayTagLabel.fontSize = 9
        awayTagLabel.fontColor = .white.withAlphaComponent(0.55)
        awayTagLabel.horizontalAlignmentMode = .left
        addChild(awayTagLabel)

        dashLabel.text = "–"
        dashLabel.fontSize = 22
        dashLabel.fontColor = .white.withAlphaComponent(0.5)
        addChild(dashLabel)

        seriesLabel.fontSize = 10
        seriesLabel.fontColor = .white.withAlphaComponent(0.65)
        addChild(seriesLabel)

        shotClockLabel.fontSize = 15
        shotClockLabel.fontColor = .yellow
        addChild(shotClockLabel)

        fireBanner.fontSize = 15
        fireBanner.fontColor = SKColor(red: 1.0, green: 0.6, blue: 0.1, alpha: 1.0)
        fireBanner.isHidden = true
        let pulse = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.55, duration: 0.32),
            SKAction.fadeAlpha(to: 1.0, duration: 0.32),
        ])
        fireBanner.run(SKAction.repeatForever(pulse))
        addChild(fireBanner)
    }

    func layout(size: CGSize) {
        let topY = size.height - 96  // clear the Dynamic Island on full-bleed layouts
        let cx = size.width / 2

        backdrop.path = CGPath(
            roundedRect: CGRect(x: cx - 105, y: topY - 68, width: 210, height: 116),
            cornerWidth: 18, cornerHeight: 18, transform: nil
        )

        homeScoreLabel.position = CGPoint(x: cx - 28, y: topY)
        awayScoreLabel.position = CGPoint(x: cx + 28, y: topY)
        homeTagLabel.position = CGPoint(x: cx - 30, y: topY + 32)
        awayTagLabel.position = CGPoint(x: cx + 30, y: topY + 32)
        dashLabel.position = CGPoint(x: cx, y: topY + 4)
        seriesLabel.position = CGPoint(x: cx, y: topY - 16)
        shotClockLabel.position = CGPoint(x: cx, y: topY - 36)
        fireBanner.position = CGPoint(x: cx, y: topY - 58)
    }

    func update(
        homeScore: Int,
        awayScore: Int,
        homeWins: Int,
        awayWins: Int,
        shotClock: Int,
        powered: Bool,
        powerRemaining: Int
    ) {
        if homeScore != lastHomeScore {
            lastHomeScore = homeScore
            homeScoreLabel.text = "\(homeScore)"
            if homeScore > 0 {
                homeScoreLabel.removeAction(forKey: "bump")
                homeScoreLabel.run(.sequence([.scale(to: 1.4, duration: 0.07), .scale(to: 1.0, duration: 0.13)]), withKey: "bump")
            }
        }
        if awayScore != lastAwayScore {
            lastAwayScore = awayScore
            awayScoreLabel.text = "\(awayScore)"
            if awayScore > 0 {
                awayScoreLabel.removeAction(forKey: "bump")
                awayScoreLabel.run(.sequence([.scale(to: 1.4, duration: 0.07), .scale(to: 1.0, duration: 0.13)]), withKey: "bump")
            }
        }
        seriesLabel.text = "SERIES \(homeWins)–\(awayWins)"
        shotClockLabel.text = shotClock > 0 ? "\(shotClock)" : ""
        shotClockLabel.fontColor = shotClock <= 3 ? .red : .yellow
        if (1...3).contains(shotClock), shotClockLabel.action(forKey: "pulse") == nil {
            let pulse = SKAction.sequence([
                SKAction.scale(to: 1.3, duration: 0.18),
                SKAction.scale(to: 1.0, duration: 0.18),
            ])
            shotClockLabel.run(SKAction.repeatForever(pulse), withKey: "pulse")
        } else if shotClock == 0 || shotClock > 3 {
            shotClockLabel.removeAction(forKey: "pulse")
            shotClockLabel.setScale(1.0)
        }

        fireBanner.isHidden = !powered
        if powered {
            fireBanner.text = "🔥 ON FIRE \(powerRemaining)s"
        }
    }
}
