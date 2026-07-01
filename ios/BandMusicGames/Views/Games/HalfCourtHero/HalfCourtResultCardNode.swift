import SpriteKit

@MainActor
final class HalfCourtResultCardNode: SKNode {
    private let bgNode = SKShapeNode(rectOf: CGSize(width: 400, height: 500), cornerRadius: 20)
    private let titleLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let scoreLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let actionButton = SKShapeNode(rectOf: CGSize(width: 240, height: 60), cornerRadius: 30)
    private let actionLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let rematchButton = SKShapeNode(rectOf: CGSize(width: 200, height: 40), cornerRadius: 20)
    private let rematchLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")

    private var onAction: (() -> Void)?
    private var onRematch: (() -> Void)?
    private var isSeriesOver = false

    init(homeScore: Int, awayScore: Int, homeWins: Int, awayWins: Int, isSeriesOver: Bool,
         stats: HalfCourtStats = HalfCourtStats(), recordBeatStreak: Int = 0, isNewStreakRecord: Bool = false,
         onAction: @escaping () -> Void, onRematch: (() -> Void)? = nil) {
        self.onAction = onAction
        self.onRematch = onRematch
        super.init()
        setup(homeScore: homeScore, awayScore: awayScore, homeWins: homeWins, awayWins: awayWins, isSeriesOver: isSeriesOver)
        addStats(stats, recordBeatStreak: recordBeatStreak, isNewStreakRecord: isNewStreakRecord)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup(homeScore: Int, awayScore: Int, homeWins: Int, awayWins: Int, isSeriesOver: Bool) {
        zPosition = 1000
        self.isSeriesOver = isSeriesOver

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
        scoreLabel.position = CGPoint(x: 0, y: 128)
        addChild(scoreLabel)

        // Visual series dots
        addSeriesDots(homeWins: homeWins, awayWins: awayWins)

        // Sub text
        let seriesText: String
        if isSeriesOver {
            seriesText = seriesWon ? "You win the series \(homeWins)–\(awayWins)!" : "CPU wins the series \(awayWins)–\(homeWins)"
        } else {
            seriesText = "Next game →"
        }
        let sub = SKLabelNode(text: seriesText)
        sub.fontSize = 14
        sub.fontColor = .white.withAlphaComponent(0.5)
        sub.position = CGPoint(x: 0, y: -20)
        addChild(sub)

        // Action Button
        actionButton.fillColor = .yellow
        actionButton.strokeColor = .clear
        actionButton.position = CGPoint(x: 0, y: -180)
        actionButton.name = "action_btn"
        addChild(actionButton)

        // Series over: the loud primary is the rematch (retention path); lobby is the ghost.
        actionLabel.text = isSeriesOver ? "RUN IT BACK" : "START NEXT GAME"
        actionLabel.fontSize = 18
        actionLabel.fontColor = .black
        actionLabel.position = CGPoint(x: 0, y: -186)
        actionLabel.verticalAlignmentMode = .center
        actionLabel.name = "action_btn"
        addChild(actionLabel)

        if isSeriesOver {
            rematchButton.fillColor = .clear
            rematchButton.strokeColor = SKColor.white.withAlphaComponent(0.22)
            rematchButton.lineWidth = 1.5
            rematchButton.position = CGPoint(x: 0, y: -228)
            rematchButton.name = "rematch_btn"
            addChild(rematchButton)

            rematchLabel.text = "BACK TO LOBBY"
            rematchLabel.fontSize = 13
            rematchLabel.fontColor = SKColor.white.withAlphaComponent(0.55)
            rematchLabel.position = CGPoint(x: 0, y: -232)
            rematchLabel.verticalAlignmentMode = .center
            rematchLabel.name = "rematch_btn"
            addChild(rematchLabel)
        }
    }

    /// Game stat line + record chase, in the empty band between the series
    /// text (y −20) and the action button (y −180).
    private func addStats(_ stats: HalfCourtStats, recordBeatStreak: Int, isNewStreakRecord: Bool) {
        func statLabel(_ text: String, x: CGFloat, y: CGFloat, size: CGFloat, alpha: CGFloat) {
            let l = SKLabelNode(fontNamed: "AvenirNext-Bold")
            l.text = text
            l.fontSize = size
            l.fontColor = SKColor.white.withAlphaComponent(alpha)
            l.position = CGPoint(x: x, y: y)
            l.verticalAlignmentMode = .center
            addChild(l)
        }
        statLabel("FG \(stats.made)/\(stats.shots) · \(stats.fgPercent)%", x: -90, y: -60, size: 13, alpha: 0.8)
        statLabel("3PT \(stats.threes)", x: 90, y: -60, size: 13, alpha: 0.8)
        statLabel("STL \(stats.steals) · BLK \(stats.blocks)", x: -90, y: -88, size: 13, alpha: 0.8)
        statLabel("BEAT STREAK \(stats.bestBeatStreak) 🔥", x: 90, y: -88, size: 13, alpha: 0.8)

        let record = SKLabelNode(fontNamed: "AvenirNext-Bold")
        record.fontSize = 12
        record.verticalAlignmentMode = .center
        record.position = CGPoint(x: 0, y: -120)
        if isNewStreakRecord && stats.bestBeatStreak > 0 {
            record.text = "NEW RECORD — BEAT STREAK \(stats.bestBeatStreak)!"
            record.fontColor = SKColor(red: 1, green: 0.84, blue: 0, alpha: 1)
            record.run(.repeatForever(.sequence([
                .scale(to: 1.06, duration: 0.3),
                .scale(to: 1.0, duration: 0.3),
            ])))
        } else {
            record.text = "BEST STREAK \(recordBeatStreak) — YOU HIT \(stats.bestBeatStreak)"
            record.fontColor = SKColor.white.withAlphaComponent(0.45)
        }
        addChild(record)
    }

    private func addSeriesDots(homeWins: Int, awayWins: Int) {
        let dotCount = 3
        let dotR: CGFloat = 10
        let dotSpacing: CGFloat = 26
        let dotY: CGFloat = 58
        let labelY: CGFloat = 42

        let homeColor = SKColor(red: 0.4, green: 0.95, blue: 0.5, alpha: 1)
        let awayColor = SKColor(red: 1, green: 0.42, blue: 0.21, alpha: 1)
        let emptyColor = SKColor(white: 1, alpha: 0.15)

        // Home dots — rightmost dot closest to center
        for i in 0..<dotCount {
            let dot = SKShapeNode(circleOfRadius: dotR)
            let filled = (dotCount - 1 - i) < homeWins
            dot.fillColor = filled ? homeColor : emptyColor
            dot.strokeColor = filled ? homeColor.withAlphaComponent(0.3) : .clear
            dot.lineWidth = 1
            dot.position = CGPoint(x: -(CGFloat(i) * dotSpacing + dotSpacing * 0.5), y: dotY)
            addChild(dot)
        }

        // Away dots — leftmost dot closest to center
        for i in 0..<dotCount {
            let dot = SKShapeNode(circleOfRadius: dotR)
            let filled = i < awayWins
            dot.fillColor = filled ? awayColor : emptyColor
            dot.strokeColor = filled ? awayColor.withAlphaComponent(0.3) : .clear
            dot.lineWidth = 1
            dot.position = CGPoint(x: CGFloat(i) * dotSpacing + dotSpacing * 0.5, y: dotY)
            addChild(dot)
        }

        // VS divider
        let vs = SKLabelNode(text: "VS")
        vs.fontName = "AvenirNext-Heavy"
        vs.fontSize = 11
        vs.fontColor = SKColor(white: 1, alpha: 0.28)
        vs.verticalAlignmentMode = .center
        vs.position = CGPoint(x: 0, y: dotY)
        addChild(vs)

        // YOU label
        let youLabel = SKLabelNode(text: "YOU")
        youLabel.fontName = "AvenirNext-Heavy"
        youLabel.fontSize = 12
        youLabel.fontColor = homeColor.withAlphaComponent(0.85)
        youLabel.horizontalAlignmentMode = .right
        youLabel.verticalAlignmentMode = .center
        youLabel.position = CGPoint(x: -(CGFloat(dotCount) * dotSpacing + dotSpacing * 0.8), y: labelY)
        addChild(youLabel)

        // CPU label
        let cpuLabel = SKLabelNode(text: "CPU")
        cpuLabel.fontName = "AvenirNext-Heavy"
        cpuLabel.fontSize = 12
        cpuLabel.fontColor = awayColor.withAlphaComponent(0.85)
        cpuLabel.horizontalAlignmentMode = .left
        cpuLabel.verticalAlignmentMode = .center
        cpuLabel.position = CGPoint(x: CGFloat(dotCount) * dotSpacing + dotSpacing * 0.8, y: labelY)
        addChild(cpuLabel)
    }

    func handleTouch(_ touch: UITouch) -> Bool {
        let location = touch.location(in: self)
        let node = atPoint(location)
        if node.name == "action_btn" {
            // Series over: primary = RUN IT BACK (rematch); mid-series: next game.
            (isSeriesOver ? onRematch : onAction)?()
            return true
        }
        if node.name == "rematch_btn" {
            // Series over: ghost = BACK TO LOBBY (dismiss).
            (isSeriesOver ? onAction : onRematch)?()
            return true
        }
        return false
    }
}
