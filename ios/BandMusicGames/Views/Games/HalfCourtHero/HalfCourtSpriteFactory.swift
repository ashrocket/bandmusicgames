import Foundation
import SpriteKit

@MainActor
enum HalfCourtSpriteFactory {
    private static let playerAtlasName = "HalfCourtHeroPlayers"
    private static let ballAtlasName = "HalfCourtHeroBall"

    private static var atlasCache: [String: SKTextureAtlas] = [:]

    static func playerTextures(heroID: HalfCourtHeroID, animation: HalfCourtAnimation) -> [SKTexture] {
        guard let frameCount = animation.playerFrameCount else { return [] }
        let names = (0..<frameCount).map {
            "\(heroID.rawValue)_\(animation.rawValue)_\(String(format: "%03d", $0))"
        }
        return textures(named: names, in: playerAtlasName)
    }

    static func ballSpinTextures() -> [SKTexture] {
        let names = (0..<12).map { "ball_spin_\(String(format: "%03d", $0))" }
        return textures(named: names, in: ballAtlasName)
    }

    private static func textures(named names: [String], in atlasName: String) -> [SKTexture] {
        guard let atlas = atlas(named: atlasName) else { return [] }
        let available = Set(atlas.textureNames)

        return names.compactMap { name in
            let candidates = ["\(name).png", name]
            guard let textureName = candidates.first(where: { available.contains($0) }) else {
                return nil
            }
            let texture = atlas.textureNamed(textureName)
            texture.filteringMode = .linear
            return texture
        }
    }

    private static let burstTexture: SKTexture = {
        let size = CGSize(width: 8, height: 8)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            SKColor.white.setFill()
            ctx.cgContext.fillEllipse(in: CGRect(origin: .zero, size: size))
        }
        return SKTexture(image: image)
    }()

    /// One-shot 12-particle gold burst for made baskets — no texture assets.
    static func goldBurst() -> SKEmitterNode {
        let e = SKEmitterNode()
        e.particleTexture = burstTexture
        e.particleBirthRate = 240
        e.numParticlesToEmit = 12
        e.particleLifetime = 0.5
        e.particleSpeed = 90
        e.particleSpeedRange = 30
        e.emissionAngleRange = .pi * 2
        e.particleAlpha = 1.0
        e.particleAlphaSpeed = -2.0
        e.particleColor = SKColor(red: 1, green: 0.84, blue: 0, alpha: 1)
        e.particleColorBlendFactor = 1
        e.particleScale = 0.75
        e.particleScaleSpeed = -0.8
        return e
    }

    private static func atlas(named name: String) -> SKTextureAtlas? {
        if let cached = atlasCache[name] { return cached }

        let atlas = SKTextureAtlas(named: name)
        guard !atlas.textureNames.isEmpty else { return nil }
        atlasCache[name] = atlas
        return atlas
    }
}

extension HalfCourtAnimation {
    var playerFrameCount: Int? {
        switch self {
        case .idle: return 4
        case .dribble: return 6
        case .run: return 6
        case .shoot: return 8
        case .celebrate: return 6
        case .jump, .land, .sad: return nil
        }
    }

    var framesPerSecond: Double {
        switch self {
        case .idle: return 7
        case .dribble: return 12
        case .run: return 12
        case .shoot: return 14
        case .celebrate: return 10
        case .jump, .land, .sad: return 10
        }
    }
}
