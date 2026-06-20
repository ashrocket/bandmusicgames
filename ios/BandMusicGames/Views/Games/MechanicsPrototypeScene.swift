import SpriteKit

/// Standalone hold-to-charge mechanics prototype.
/// No characters, no ball, no lobby — just the meter.
@MainActor
final class MechanicsPrototypeScene: SKScene {

    // MARK: - Tune these

    private let chargeDuration: TimeInterval = 1.8
    private let sweetLow:  CGFloat = 0.40
    private let sweetHigh: CGFloat = 0.75
    private let warnHigh:  CGFloat = 0.90

    // MARK: - State

    private var charging = false
    private var chargeStart: TimeInterval = 0
    private var charge: CGFloat = 0
    private var lastFrameTime: TimeInterval = 0

    // MARK: - Meter geometry (set in didMove)

    private var mW: CGFloat = 0
    private var mH: CGFloat = 0
    private var mX: CGFloat = 0  // left edge of track
    private var mY: CGFloat = 0  // bottom edge of track

    // MARK: - Nodes

    private var fillNode: SKSpriteNode!
    private var fillGlowA: SKSpriteNode!   // wide soft glow
    private var fillGlowB: SKSpriteNode!   // tighter inner glow
    private var glowEffectA: SKEffectNode!
    private var glowEffectB: SKEffectNode!
    private var pulseRing: SKShapeNode!
    private var sweetZone: SKShapeNode!
    private var pctLabel: SKLabelNode!
    private var feedLabel: SKLabelNode!
    private var hintLabel: SKLabelNode!
    private var holdLabel: SKLabelNode!
    private var bg: SKShapeNode!
    private var ringActive = false

    // MARK: - Setup

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.06, green: 0.07, blue: 0.10, alpha: 1)
        buildBackground()
        buildMeter()
        buildLabels()
        buildPulseRing()
    }

    private func buildBackground() {
        // Subtle court lines atmosphere
        for i in 0..<4 {
            let line = SKShapeNode(rectOf: CGSize(width: size.width * 1.4, height: 1))
            line.fillColor = SKColor(white: 1, alpha: 0.03)
            line.strokeColor = .clear
            line.position = CGPoint(x: size.width / 2, y: size.height * 0.2 + CGFloat(i) * size.height * 0.2)
            addChild(line)
        }
    }

    private func buildMeter() {
        let sc = size
        mW = max(28, sc.width * 0.065)
        mH = sc.height * 0.62
        mX = 20 + mW / 2   // center of bar
        mY = sc.height * 0.17

        // -- Track shadow
        let shadow = SKShapeNode(rectOf: CGSize(width: mW + 12, height: mH + 12),
                                 cornerRadius: mW / 2 + 6)
        shadow.fillColor = .black.withAlphaComponent(0.45)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: mX, y: mY + mH / 2)
        addChild(shadow)

        // -- Track background
        let track = SKShapeNode(rectOf: CGSize(width: mW, height: mH), cornerRadius: mW / 2)
        track.fillColor = SKColor(white: 1, alpha: 0.06)
        track.strokeColor = SKColor(white: 1, alpha: 0.14)
        track.lineWidth = 1.5
        track.position = CGPoint(x: mX, y: mY + mH / 2)
        addChild(track)

        // -- Sweet-spot zone highlight
        let zoneY = mY + mH * sweetLow
        let zoneH = mH * (sweetHigh - sweetLow)
        sweetZone = SKShapeNode(rectOf: CGSize(width: mW - 4, height: zoneH), cornerRadius: 5)
        sweetZone.fillColor = SKColor(red: 0.28, green: 1.0, blue: 0.5, alpha: 0.12)
        sweetZone.strokeColor = SKColor(red: 0.35, green: 1.0, blue: 0.55, alpha: 0.30)
        sweetZone.lineWidth = 1.0
        sweetZone.position = CGPoint(x: mX, y: zoneY + zoneH / 2)
        addChild(sweetZone)

        // -- Tick marks
        addTick(frac: sweetLow,  color: SKColor(red: 0.35, green: 1.0, blue: 0.5, alpha: 0.65))
        addTick(frac: sweetHigh, color: SKColor(red: 0.35, green: 1.0, blue: 0.5, alpha: 0.65))
        addTick(frac: warnHigh,  color: SKColor(red: 1.0,  green: 0.55, blue: 0.1, alpha: 0.65))

        // -- Zone labels (rotated, left of bar)
        addSideLabel("PERFECT",    x: mX - mW / 2 - 18, y: mY + mH * (sweetLow + sweetHigh) / 2,
                     color: SKColor(red: 0.3, green: 1.0, blue: 0.5, alpha: 0.55))
        addSideLabel("WARN",       x: mX - mW / 2 - 18, y: mY + mH * (sweetHigh + warnHigh) / 2,
                     color: SKColor(red: 1.0, green: 0.65, blue: 0.1, alpha: 0.55))

        // -- Glow A: wide soft bloom
        glowEffectA = buildGlowEffect(radius: 20)
        addChild(glowEffectA)
        fillGlowA = barNode(color: fillColor(0), width: mW * 3.5, height: mH)
        glowEffectA.addChild(fillGlowA)

        // -- Glow B: tight inner glow
        glowEffectB = buildGlowEffect(radius: 7)
        addChild(glowEffectB)
        fillGlowB = barNode(color: fillColor(0), width: mW * 1.6, height: mH)
        glowEffectB.addChild(fillGlowB)

        // -- Solid fill (top layer)
        fillNode = barNode(color: fillColor(0), width: mW - 4, height: mH)
        addChild(fillNode)
    }

    private func buildGlowEffect(radius: Double) -> SKEffectNode {
        let e = SKEffectNode()
        if let blur = CIFilter(name: "CIGaussianBlur") {
            blur.setValue(radius, forKey: "inputRadius")
            e.filter = blur
        }
        e.shouldRasterize = true
        e.shouldEnableEffects = true
        e.alpha = 0
        return e
    }

    private func barNode(color: SKColor, width: CGFloat, height: CGFloat) -> SKSpriteNode {
        let n = SKSpriteNode(color: color, size: CGSize(width: width, height: height))
        n.anchorPoint = CGPoint(x: 0.5, y: 0)
        n.position = CGPoint(x: mX, y: mY)
        n.yScale = 0.0001
        return n
    }

    private func addTick(frac: CGFloat, color: SKColor) {
        let tick = SKShapeNode(rectOf: CGSize(width: mW + 10, height: 1.5))
        tick.fillColor = color
        tick.strokeColor = .clear
        tick.position = CGPoint(x: mX, y: mY + mH * frac)
        addChild(tick)
    }

    private func addSideLabel(_ text: String, x: CGFloat, y: CGFloat, color: SKColor) {
        let n = SKLabelNode(text: text)
        n.fontSize = 8
        n.fontName = "AvenirNext-Bold"
        n.fontColor = color
        n.verticalAlignmentMode = .center
        n.horizontalAlignmentMode = .center
        n.position = CGPoint(x: x, y: y)
        n.zRotation = .pi / 2
        addChild(n)
    }

    private func buildLabels() {
        let cx = size.width * 0.58
        let cy = size.height * 0.5

        holdLabel = makeLabel("", size: 14, at: CGPoint(x: cx, y: cy + 68), color: SKColor(white: 1, alpha: 0.22))
        addChild(holdLabel)

        pctLabel = makeLabel("", size: 56, at: CGPoint(x: cx, y: cy + 4), color: .white)
        pctLabel.alpha = 0
        addChild(pctLabel)

        feedLabel = makeLabel("", size: 24, at: CGPoint(x: cx, y: cy - 54), color: .white)
        feedLabel.alpha = 0
        addChild(feedLabel)

        hintLabel = makeLabel("TAP & HOLD", size: 17, at: CGPoint(x: cx, y: cy - 14),
                              color: SKColor(white: 1, alpha: 0.28))
        addChild(hintLabel)
    }

    private func buildPulseRing() {
        pulseRing = SKShapeNode(circleOfRadius: mW * 1.4)
        pulseRing.strokeColor = SKColor(red: 0.3, green: 1.0, blue: 0.5, alpha: 0.8)
        pulseRing.lineWidth = 2.0
        pulseRing.fillColor = .clear
        pulseRing.alpha = 0
        pulseRing.position = CGPoint(x: mX, y: mY + mH * (sweetLow + sweetHigh) / 2)
        addChild(pulseRing)
    }

    private func makeLabel(_ text: String, size: CGFloat, at pos: CGPoint, color: SKColor) -> SKLabelNode {
        let n = SKLabelNode(text: text)
        n.fontSize = size
        n.fontName = "AvenirNext-Bold"
        n.fontColor = color
        n.horizontalAlignmentMode = .center
        n.verticalAlignmentMode = .center
        n.position = pos
        return n
    }

    // MARK: - Color

    private func fillColor(_ c: CGFloat) -> SKColor {
        if c < sweetLow  { return SKColor(red: 0.38, green: 0.65, blue: 1.00, alpha: 1) }
        if c < sweetHigh { return SKColor(red: 0.25, green: 0.98, blue: 0.50, alpha: 1) }
        if c < warnHigh  { return SKColor(red: 1.00, green: 0.70, blue: 0.12, alpha: 1) }
        return               SKColor(red: 1.00, green: 0.25, blue: 0.12, alpha: 1)
    }

    // MARK: - Touch

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !charging else { return }
        charging = true
        chargeStart = 0
        charge = 0

        hintLabel.run(SKAction.fadeOut(withDuration: 0.2))
        feedLabel.run(SKAction.fadeOut(withDuration: 0.15))
        pctLabel.run(SKAction.fadeAlpha(to: 1, duration: 0.18))

        let appear = SKAction.group([
            SKAction.fadeAlpha(to: 0.7, duration: 0.25),
        ])
        glowEffectA.run(appear)
        glowEffectB.run(appear)

        holdLabel.text = "HOLD"
        holdLabel.run(SKAction.fadeAlpha(to: 1, duration: 0.15))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard charging else { return }
        release()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard charging else { return }
        release()
    }

    private func release() {
        charging = false
        let c = charge
        showFeedback(for: c)
        animateReset()
        holdLabel.run(SKAction.fadeOut(withDuration: 0.15))
    }

    // MARK: - Update

    override func update(_ currentTime: TimeInterval) {
        guard charging else { return }
        if chargeStart == 0 { chargeStart = currentTime }
        charge = min(1.0, CGFloat((currentTime - chargeStart) / chargeDuration))
        updateMeter(charge)
        lastFrameTime = currentTime
    }

    private func updateMeter(_ c: CGFloat) {
        let color = fillColor(c)

        fillNode.color  = color
        fillGlowA.color = color
        fillGlowB.color = color

        fillNode.yScale  = c
        fillGlowA.yScale = c
        fillGlowB.yScale = c

        pctLabel.text      = "\(Int(c * 100))%"
        pctLabel.fontColor = color

        let inSweet = c >= sweetLow && c < sweetHigh
        let inWarn  = c >= sweetHigh && c < warnHigh
        let inRed   = c >= warnHigh

        // Glow alpha
        let baseGlow: CGFloat = c * 0.55
        let sweetBoost: CGFloat = inSweet ? (c - sweetLow) / (sweetHigh - sweetLow) * 0.45 : 0
        glowEffectA.alpha = min(1, baseGlow + sweetBoost)
        glowEffectB.alpha = min(1, (baseGlow + sweetBoost) * 1.3)

        // Pulse ring in sweet spot
        if inSweet && !ringActive {
            ringActive = true
            pulseRing.strokeColor = SKColor(red: 0.3, green: 1.0, blue: 0.5, alpha: 0.85)
            startPulse()
        } else if inWarn && ringActive {
            ringActive = false
            pulseRing.strokeColor = SKColor(red: 1.0, green: 0.7, blue: 0.15, alpha: 0.85)
            pulseRing.removeAllActions()
            pulseRing.run(SKAction.fadeOut(withDuration: 0.2))
        } else if inRed && !ringActive {
            // Shake the bar a little
        } else if !inSweet && !inWarn && !inRed && ringActive {
            ringActive = false
            pulseRing.removeAllActions()
            pulseRing.run(SKAction.fadeOut(withDuration: 0.2))
        }
    }

    private func startPulse() {
        pulseRing.setScale(0.65)
        pulseRing.alpha = 0
        let pulse = SKAction.sequence([
            SKAction.group([
                SKAction.fadeAlpha(to: 0.85, duration: 0.08),
                SKAction.scale(to: 0.65, duration: 0.08),
            ]),
            SKAction.group([
                SKAction.scale(to: 1.65, duration: 0.55),
                SKAction.fadeOut(withDuration: 0.55),
            ]),
        ])
        pulseRing.run(SKAction.repeatForever(pulse))
    }

    // MARK: - Feedback

    private func showFeedback(for c: CGFloat) {
        let text: String
        let color: SKColor

        if c < 0.12 {
            text = "TOO WEAK"
            color = SKColor(white: 0.45, alpha: 1)
        } else if c < sweetLow {
            text = "NEEDS MORE"
            color = SKColor(red: 0.45, green: 0.72, blue: 1.0, alpha: 1)
        } else if c <= sweetHigh {
            text = "PERFECT!"
            color = SKColor(red: 0.28, green: 1.0, blue: 0.52, alpha: 1)
            flashScreen(color: color.withAlphaComponent(0.07))
            spawnBurst(color: color)
        } else if c <= warnHigh {
            text = "A BIT HIGH"
            color = SKColor(red: 1.0, green: 0.72, blue: 0.12, alpha: 1)
        } else {
            text = "OVERSHOOT!"
            color = SKColor(red: 1.0, green: 0.28, blue: 0.12, alpha: 1)
            flashScreen(color: color.withAlphaComponent(0.09))
        }

        feedLabel.text      = text
        feedLabel.fontColor = color
        feedLabel.setScale(1.5)
        feedLabel.alpha = 1
        feedLabel.run(SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 1.0, duration: 0.22),
            ]),
            SKAction.wait(forDuration: 0.9),
            SKAction.fadeOut(withDuration: 0.4),
            SKAction.run { [weak self] in
                self?.hintLabel.run(SKAction.fadeAlpha(to: 0.28, duration: 0.35))
            },
        ]))

        pctLabel.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.25),
            SKAction.fadeOut(withDuration: 0.25),
        ]))
    }

    private func animateReset() {
        let dur: TimeInterval = 0.45
        fillNode.run(SKAction.scaleY(to: 0.0001, duration: dur))
        fillGlowA.run(SKAction.scaleY(to: 0.0001, duration: dur))
        fillGlowB.run(SKAction.scaleY(to: 0.0001, duration: dur))
        glowEffectA.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.1),
            SKAction.fadeOut(withDuration: dur - 0.1),
        ]))
        glowEffectB.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.1),
            SKAction.fadeOut(withDuration: dur - 0.1),
        ]))
        ringActive = false
        pulseRing.removeAllActions()
        pulseRing.run(SKAction.fadeOut(withDuration: 0.18))
        charge = 0
    }

    private func flashScreen(color: SKColor) {
        let flash = SKShapeNode(rectOf: size)
        flash.fillColor = color
        flash.strokeColor = .clear
        flash.position = CGPoint(x: size.width / 2, y: size.height / 2)
        flash.zPosition = 100
        addChild(flash)
        flash.run(SKAction.sequence([
            SKAction.fadeIn(withDuration: 0.04),
            SKAction.fadeOut(withDuration: 0.28),
            SKAction.removeFromParent(),
        ]))
    }

    private func spawnBurst(color: SKColor) {
        let cx = mX
        let cy = mY + mH * ((sweetLow + sweetHigh) / 2)

        for i in 0..<16 {
            let angle = CGFloat(i) / 16 * .pi * 2 + CGFloat.random(in: -0.2...0.2)
            let dot = SKShapeNode(circleOfRadius: CGFloat.random(in: 3...6))
            dot.fillColor = color.withAlphaComponent(CGFloat.random(in: 0.6...0.95))
            dot.strokeColor = .clear
            dot.position = CGPoint(x: cx, y: cy)
            dot.zPosition = 50
            addChild(dot)

            let dist = CGFloat.random(in: 50...130)
            let tx = cx + cos(angle) * dist
            let ty = cy + sin(angle) * dist
            dot.run(SKAction.sequence([
                SKAction.group([
                    SKAction.move(to: CGPoint(x: tx, y: ty), duration: 0.55),
                    SKAction.sequence([
                        SKAction.wait(forDuration: 0.25),
                        SKAction.fadeOut(withDuration: 0.3),
                    ]),
                    SKAction.scale(to: 0.15, duration: 0.55),
                ]),
                SKAction.removeFromParent(),
            ]))
        }
    }
}
