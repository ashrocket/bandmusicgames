import Foundation
import SpriteKit
import SwiftUI

/// Puppet-animated player using the full-body Lizzy McGuire cartoon sprites
/// from the web game (one painted pose per character, animated procedurally
/// with bob / lean / squash-and-stretch — the same math as the web build).
@MainActor
final class PlayerNode: SKNode {
    let heroID: HalfCourtHeroID
    let team: HalfCourtTeam
    /// Standing height of the character on screen, in points.
    let playerHeight: CGFloat
    private var character: HalfCourtHero { heroID.character }

    /// The web game's animation constants are in pixels for a ~175px-tall
    /// character; everything scales by this factor.
    private var k: CGFloat { playerHeight / 175 }

    private let bodyContainer = SKNode()   // facing flip lives here
    private let puppet = SKNode()          // bob / lean / squash transforms
    private let shadowNode: SKShapeNode
    private let selectionRing: SKShapeNode
    private var spriteNode: SKSpriteNode?
    private var fireAura: SKShapeNode?

    private enum PuppetAnim {
        case idle
        case run
        case shoot
        case land
        case celebrate
        case sad
    }

    private var anim: PuppetAnim = .idle
    private var oneShotUntil: TimeInterval = 0
    private var oneShotStart: TimeInterval = 0
    private var landStart: TimeInterval = 0
    private var lastTickTime: TimeInterval = 0

    /// 0...1 — how hard the player is running; drives run-cycle intensity.
    var moveIntensity: CGFloat = 0.75

    var facing: CGFloat = 1 {
        didSet {
            guard facing != 0 else { facing = oldValue; return }
            facing = facing > 0 ? 1 : -1
            bodyContainer.xScale = abs(bodyContainer.xScale) * facing
        }
    }

    init(heroID: HalfCourtHeroID, team: HalfCourtTeam, spriteSize: CGFloat = 170) {
        self.heroID = heroID
        self.team = team
        self.playerHeight = spriteSize
        let shadowW = spriteSize * 0.42
        shadowNode = SKShapeNode(ellipseIn: CGRect(x: -shadowW / 2, y: -7, width: shadowW, height: 14))
        let ringW = spriteSize * 0.5
        selectionRing = SKShapeNode(ellipseIn: CGRect(x: -ringW / 2, y: -12, width: ringW, height: 24))
        super.init()
        setup()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        shadowNode.fillColor = .black.withAlphaComponent(0.25)
        shadowNode.strokeColor = .clear
        addChild(shadowNode)

        selectionRing.strokeColor = SKColor(character.hue).withAlphaComponent(0.85)
        selectionRing.lineWidth = 3
        selectionRing.isHidden = true
        addChild(selectionRing)

        addChild(bodyContainer)
        bodyContainer.addChild(puppet)
        installSpriteBody()
    }

    private func installSpriteBody() {
        let imageName = "hch_\(heroID.rawValue)"
        guard UIImage(named: imageName) != nil else { return }

        let texture = SKTexture(imageNamed: imageName)
        texture.filteringMode = .linear
        let aspect = texture.size().width / max(texture.size().height, 1)
        let sprite = SKSpriteNode(texture: texture)
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0)  // feet on the ground
        sprite.size = CGSize(width: playerHeight * aspect, height: playerHeight)
        sprite.name = "halfcourt-\(heroID.rawValue)-sprite"
        puppet.addChild(sprite)
        spriteNode = sprite
    }

    func setSelectionActive(_ active: Bool) {
        selectionRing.isHidden = !active
    }

    // MARK: - Animation state

    /// Loop animations; one-shots in flight (shoot/celebrate) are not interrupted.
    func updateLocomotion(moving: Bool, hasBall: Bool) {
        guard lastTickTime >= oneShotUntil else { return }
        anim = moving ? .run : .idle
    }

    func setAnimation(_ animation: HalfCourtAnimation) {
        guard lastTickTime >= oneShotUntil else { return }
        anim = puppetAnim(for: animation)
    }

    func playAnimationOnce(_ animation: HalfCourtAnimation) {
        anim = puppetAnim(for: animation)
        let duration: TimeInterval
        switch animation {
        case .shoot: duration = 0.55
        case .celebrate: duration = 1.1
        case .sad: duration = 1.2
        default: duration = 0.4
        }
        oneShotStart = lastTickTime
        oneShotUntil = lastTickTime + duration
    }

    private func puppetAnim(for animation: HalfCourtAnimation) -> PuppetAnim {
        switch animation {
        case .run: return .run
        case .shoot, .jump: return .shoot
        case .celebrate: return .celebrate
        case .sad: return .sad
        case .idle, .dribble, .land: return .idle
        }
    }

    /// Drive the puppet — call once per frame with the scene clock.
    /// Ported from the web build's drawChar transform block.
    func tick(now: TimeInterval) {
        lastTickTime = now
        if now >= oneShotUntil {
            switch anim {
            case .shoot:
                // Touch down from the jumper into a landing squash
                anim = .land
                landStart = now
                oneShotUntil = now + 0.28
            case .land, .celebrate, .sad:
                anim = .idle
            case .idle, .run:
                break
            }
        }

        let f = CGFloat(now * 60)  // web "frame" counter equivalent
        var scX: CGFloat = 1
        var scY: CGFloat = 1
        var bobY: CGFloat = 0     // web is y-down: negative = up
        var lean: CGFloat = 0

        switch anim {
        case .idle:
            let phase = f * 0.05
            bobY = sin(phase) * 3.5
            scX = 1 + sin(phase) * 0.012
            scY = 1 - sin(phase) * 0.012
        case .run:
            let phase = f * 0.20
            let intensity = min(1, max(0.2, moveIntensity))
            bobY = -abs(sin(phase)) * 5 * intensity
            lean = sin(phase) * 0.06 * intensity
            let sq = cos(phase)
            scX = 1 + sq * 0.03 * intensity
            scY = 1 - sq * 0.02 * intensity
        case .shoot:
            // Rise into the jumper: stretch + a sine-arc hop, peak at release
            let t = min(1, max(0, CGFloat((now - oneShotStart) / 0.55)))
            bobY = -10 - sin(.pi * t) * 26
            scX = 0.90
            scY = 1.12
        case .land:
            // Web-game landing squash, decaying over ~17 frames
            let t = min(1, max(0, CGFloat((now - landStart) / 0.28)))
            scX = 1 + (1 - t) * 0.22
            scY = 1 - (1 - t) * 0.20
            bobY = (1 - t) * 6
        case .celebrate:
            let phase = f * 0.22
            let lift = abs(sin(phase))
            bobY = -lift * 16
            scX = 1 + (1 - lift) * 0.13 - lift * 0.04
            scY = 1 - (1 - lift) * 0.09 + lift * 0.07
        case .sad:
            bobY = 6
            scX = 1.05
            scY = 0.92
        }

        puppet.position = CGPoint(x: 0, y: -bobY * k)
        puppet.xScale = scX
        puppet.yScale = scY
        puppet.zRotation = -lean
        shadowNode.xScale = scX
        shadowNode.alpha = max(0.12, 0.25 + bobY * 0.006)
    }

    // MARK: - Ball attachment points (web-game geometry, scaled)

    /// Where the ball sits while dribbling, in this node's coordinates.
    /// Web: hand at (30, -78), floor at (30, -10), eased by |sin| bounce.
    func ballCarryPoint(bouncePhase: CGFloat) -> CGPoint {
        let dribPct = abs(sin(bouncePhase))
        let y = (10 + (78 - 10) * dribPct) * k
        return CGPoint(x: facing * 30 * k, y: y)
    }

    /// Where the ball leaves the hand on a shot. Web: (18, -175) — overhead.
    func shotReleasePoint() -> CGPoint {
        CGPoint(x: facing * 18 * k, y: 175 * k)
    }

    // MARK: - Power-up aura

    func setOnFire(_ on: Bool) {
        if on {
            guard fireAura == nil else { return }
            let w = playerHeight * 0.62
            let aura = SKShapeNode(ellipseIn: CGRect(x: -w / 2, y: -6, width: w, height: playerHeight * 0.95))
            aura.fillColor = SKColor(red: 1.0, green: 0.45, blue: 0.08, alpha: 0.15)
            aura.strokeColor = SKColor(red: 1.0, green: 0.7, blue: 0.15, alpha: 0.6)
            aura.lineWidth = 2.5
            aura.zPosition = -1
            let pulse = SKAction.sequence([
                SKAction.group([SKAction.scaleX(to: 1.12, duration: 0.22), SKAction.fadeAlpha(to: 0.7, duration: 0.22)]),
                SKAction.group([SKAction.scaleX(to: 0.95, duration: 0.22), SKAction.fadeAlpha(to: 1.0, duration: 0.22)]),
            ])
            aura.run(SKAction.repeatForever(pulse))
            insertChild(aura, at: 0)
            fireAura = aura
            spriteNode?.color = SKColor(red: 1.0, green: 0.55, blue: 0.12, alpha: 1)
            spriteNode?.colorBlendFactor = 0.16
        } else {
            fireAura?.removeFromParent()
            fireAura = nil
            spriteNode?.colorBlendFactor = 0
        }
    }
}
