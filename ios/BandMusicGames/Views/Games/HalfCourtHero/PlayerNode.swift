import Foundation
import SpriteKit
import SwiftUI

/// Puppet-animated player with SpriteKit atlas frame overlay.
/// When `HalfCourtHeroPlayers.atlas` is compiled into the bundle, atlas frames
/// are played for looping animations (idle, run, dribble, shoot, celebrate).
/// The puppet layer (bob / lean / squash-and-stretch) runs on top regardless.
@MainActor
final class PlayerNode: SKNode {
    let heroID: HalfCourtHeroID
    let team: HalfCourtTeam
    let playerHeight: CGFloat
    private var nbaJerseysEnabled: Bool
    private var character: HalfCourtHero { heroID.character }

    private var k: CGFloat { playerHeight / 175 }

    private let bodyContainer = SKNode()
    private let puppet = SKNode()
    private let shadowNode: SKShapeNode
    private let selectionRing: SKShapeNode
    private var spriteNode: SKSpriteNode?
    private var fireAura: SKShapeNode?

    // Atlas animation state
    private var atlasTextureCache: [String: [SKTexture]] = [:]
    private var useAtlas = false

    private enum PuppetAnim {
        case idle, dribble, run, shoot, land, celebrate, sad
    }

    private var anim: PuppetAnim = .idle {
        didSet {
            guard anim != oldValue else { return }
            syncAtlasToAnim()
        }
    }
    private var oneShotUntil: TimeInterval = 0
    private var oneShotStart: TimeInterval = 0
    private var landStart: TimeInterval = 0
    private var lastTickTime: TimeInterval = 0

    var moveIntensity: CGFloat = 0.75

    var facing: CGFloat = 1 {
        didSet {
            guard facing != 0 else { facing = oldValue; return }
            facing = facing > 0 ? 1 : -1
            bodyContainer.xScale = abs(bodyContainer.xScale) * facing
        }
    }

    init(heroID: HalfCourtHeroID, team: HalfCourtTeam, spriteSize: CGFloat = 170, nbaJerseys: Bool = false) {
        self.heroID = heroID
        self.team = team
        self.playerHeight = spriteSize
        self.nbaJerseysEnabled = nbaJerseys
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
        let imageName: String
        if nbaJerseysEnabled {
            let teamKey = team == .home ? "knicks" : "spurs"
            let teamImageName = "hch_\(heroID.rawValue)_\(teamKey)"
            imageName = UIImage(named: teamImageName) != nil ? teamImageName : "hch_\(heroID.rawValue)"
        } else {
            imageName = "hch_\(heroID.rawValue)"
        }
        guard UIImage(named: imageName) != nil else { return }

        let texture = SKTexture(imageNamed: imageName)
        texture.filteringMode = .linear
        let aspect = texture.size().width / max(texture.size().height, 1)
        let sprite = SKSpriteNode(texture: texture)
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0)
        sprite.size = CGSize(width: playerHeight * aspect, height: playerHeight)
        sprite.name = "halfcourt-\(heroID.rawValue)-sprite"
        puppet.addChild(sprite)
        spriteNode = sprite

        setupAtlas()
    }

    // MARK: - Atlas animation

    private func setupAtlas() {
        let atlas = SKTextureAtlas(named: "HalfCourtHeroPlayers")
        let key = heroID.rawValue
        let availableNames = Set(atlas.textureNames)
        guard availableNames.contains("\(key)_idle_000") else { return }

        useAtlas = true

        // Atlas frames are 256×256 square; character body fills ~82% of height,
        // feet sit at ~14% from the bottom edge.
        let atlasSize = playerHeight / 0.82
        spriteNode?.size = CGSize(width: atlasSize, height: atlasSize)
        spriteNode?.anchorPoint = CGPoint(x: 0.5, y: 0.14)

        let animDefs: [(String, Int)] = [
            ("idle", 8), ("run", 8), ("dribble", 8), ("shoot", 10), ("celebrate", 8),
        ]
        for (animKey, count) in animDefs {
            let frames: [SKTexture] = (0..<count).compactMap { i in
                let name = "\(key)_\(animKey)_\(String(format: "%03d", i))"
                guard availableNames.contains(name) else { return nil }
                let tex = atlas.textureNamed(name)
                tex.filteringMode = .linear
                return tex
            }
            if !frames.isEmpty {
                atlasTextureCache[animKey] = frames
            }
        }

        playAtlasAnim("idle", fps: 8, loop: true)
    }

    private func playAtlasAnim(_ animKey: String, fps: Double, loop: Bool) {
        guard useAtlas, let frames = atlasTextureCache[animKey], !frames.isEmpty else { return }
        spriteNode?.removeAction(forKey: "atlasAnim")
        let animate = SKAction.animate(with: frames, timePerFrame: 1.0 / fps)
        let action = loop ? SKAction.repeatForever(animate) : animate
        spriteNode?.run(action, withKey: "atlasAnim")
    }

    private func syncAtlasToAnim() {
        guard useAtlas else { return }
        switch anim {
        case .idle:
            playAtlasAnim("idle", fps: 8, loop: true)
        case .dribble:
            playAtlasAnim("dribble", fps: 14, loop: true)
        case .run:
            playAtlasAnim("run", fps: 14, loop: true)
        case .shoot:
            playAtlasAnim("shoot", fps: 16, loop: false)
        case .celebrate:
            playAtlasAnim("celebrate", fps: 12, loop: true)
        case .sad:
            // Play idle at half-speed for sad state
            guard let frames = atlasTextureCache["idle"], !frames.isEmpty else { return }
            spriteNode?.removeAction(forKey: "atlasAnim")
            let animate = SKAction.animate(with: frames, timePerFrame: 1.0 / 4)
            spriteNode?.run(SKAction.repeatForever(animate), withKey: "atlasAnim")
        case .land:
            break  // keep current frame while puppet handles landing squash
        }
    }

    func setSelectionActive(_ active: Bool) {
        selectionRing.isHidden = !active
    }

    func reloadSprite(nbaJerseys: Bool) {
        nbaJerseysEnabled = nbaJerseys
        spriteNode?.removeFromParent()
        spriteNode = nil
        atlasTextureCache = [:]
        useAtlas = false
        installSpriteBody()
    }

    // MARK: - Animation state

    func updateLocomotion(moving: Bool, hasBall: Bool) {
        guard lastTickTime >= oneShotUntil else { return }
        if hasBall && !moving {
            anim = .dribble
        } else {
            anim = moving ? .run : .idle
        }
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
        case .dribble: return .dribble
        case .shoot, .jump: return .shoot
        case .celebrate: return .celebrate
        case .sad: return .sad
        case .idle, .land: return .idle
        }
    }

    func tick(now: TimeInterval) {
        lastTickTime = now
        if now >= oneShotUntil {
            switch anim {
            case .shoot:
                anim = .land
                landStart = now
                oneShotUntil = now + 0.28
            case .land, .celebrate, .sad:
                anim = .idle
            case .idle, .dribble, .run:
                break
            }
        }

        let f = CGFloat(now * 60)
        var scX: CGFloat = 1
        var scY: CGFloat = 1
        var bobY: CGFloat = 0
        var lean: CGFloat = 0

        switch anim {
        case .idle:
            let phase = f * 0.05
            bobY = sin(phase) * 3.5
            scX = 1 + sin(phase) * 0.012
            scY = 1 - sin(phase) * 0.012
        case .dribble:
            let phase = f * 0.08
            bobY = sin(phase) * 2.5
            scX = 1 + sin(phase) * 0.008
            scY = 1 - sin(phase) * 0.008
        case .run:
            let phase = f * 0.20
            let intensity = min(1, max(0.2, moveIntensity))
            bobY = -abs(sin(phase)) * 5 * intensity
            lean = sin(phase) * 0.06 * intensity
            let sq = cos(phase)
            scX = 1 + sq * 0.03 * intensity
            scY = 1 - sq * 0.02 * intensity
        case .shoot:
            let t = min(1, max(0, CGFloat((now - oneShotStart) / 0.55)))
            bobY = -10 - sin(.pi * t) * 26
            scX = 0.90
            scY = 1.12
        case .land:
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

    // MARK: - Ball attachment points

    func ballCarryPoint(bouncePhase: CGFloat) -> CGPoint {
        let dribPct = abs(sin(bouncePhase))
        let y = (10 + (78 - 10) * dribPct) * k
        return CGPoint(x: facing * 30 * k, y: y)
    }

    func shotReleasePoint() -> CGPoint {
        CGPoint(x: facing * 18 * k, y: 175 * k)
    }

    /// Brief white flash — "you touched it but didn't get it" steal feedback.
    func flashGlint() {
        guard let spriteNode else { return }
        spriteNode.removeAction(forKey: "glint")
        spriteNode.color = .white
        spriteNode.colorBlendFactor = 0.55
        spriteNode.run(.sequence([
            .wait(forDuration: 0.05),
            .customAction(withDuration: 0.25) { node, t in
                (node as? SKSpriteNode)?.colorBlendFactor = 0.55 * (1 - t / 0.25)
            },
        ]), withKey: "glint")
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
