import SpriteKit
import UIKit

@MainActor
enum GoonRenderer {

    static let tileSize: CGFloat = 32

    /// Look up a sprite by name; if no texture atlas is present yet,
    /// return a colored shape-node fallback so day-1 build is playable.
    static func sprite(named name: String, size: CGSize, fallbackColor: SKColor) -> SKNode {
        if let texture = textureIfAvailable(name) {
            let node = SKSpriteNode(texture: texture, size: size)
            node.texture?.filteringMode = .nearest
            node.name = name
            return node
        }
        let shape = SKShapeNode(rectOf: size, cornerRadius: 2)
        shape.fillColor = fallbackColor
        shape.strokeColor = .clear
        shape.name = name
        return shape
    }

    static func tileNode(for tile: GoonTile, x: Int, y: Int) -> SKNode {
        let size = CGSize(width: tileSize, height: tileSize)
        let variant = grassVariant(x: x, y: y)
        switch tile {
        case .tall:
            let node = sprite(
                named: firstAvailableTextureName(["tile-tall-\(variant)", "tile-tall-1"]),
                size: size,
                fallbackColor: tallGrassColor(for: variant)
            )
            applyGrassTint(to: node, variant: variant, cut: false)
            runTallGrassWind(on: node, x: x, y: y)
            return node
        case .cut:
            let node = sprite(
                named: firstAvailableTextureName(["tile-cut-\(variant)", "tile-cut-1"]),
                size: size,
                fallbackColor: cutGrassColor(for: variant)
            )
            applyGrassTint(to: node, variant: variant, cut: true)
            return node
        case .stump:
            return sprite(named: "stump-full", size: size, fallbackColor: SKColor(red: 0.55, green: 0.27, blue: 0.07, alpha: 1))
        case .house:
            return sprite(named: "tile-house-wall", size: size, fallbackColor: SKColor(red: 0.4, green: 0.3, blue: 0.2, alpha: 1))
        case .garden:
            return sprite(named: "tile-garden-1", size: size, fallbackColor: SKColor(red: 0.6, green: 0.4, blue: 0.7, alpha: 1))
        }
    }

    static func runCutSettleAnimation(on node: SKNode) {
        node.removeAction(forKey: "grass-wind")
        node.setScale(1.07)
        node.alpha = 0.72
        let settle = SKAction.group([
            SKAction.scale(to: 1.0, duration: 0.18),
            SKAction.fadeAlpha(to: 1.0, duration: 0.18),
        ])
        settle.timingMode = .easeOut
        node.run(settle, withKey: "cut-settle")
    }

    static func clippingEmitter() -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.particleTexture = clippingTexture
        emitter.numParticlesToEmit = 14
        emitter.particleBirthRate = 180
        emitter.particleLifetime = 0.28
        emitter.particleLifetimeRange = 0.12
        emitter.particleSpeed = 82
        emitter.particleSpeedRange = 44
        emitter.emissionAngleRange = .pi * 2
        emitter.particleAlpha = 0.95
        emitter.particleAlphaRange = 0.18
        emitter.particleAlphaSpeed = -2.6
        emitter.particleScale = 0.85
        emitter.particleScaleRange = 0.22
        emitter.particleScaleSpeed = -1.4
        emitter.particleRotationRange = .pi
        emitter.particleRotationSpeed = 7
        emitter.particleColor = SKColor(red: 0.35, green: 0.82, blue: 0.23, alpha: 1)
        emitter.particleColorBlendFactor = 1
        emitter.zPosition = 8
        return emitter
    }

    static func grassVariant(x: Int, y: Int) -> Int {
        abs((x * 37 + y * 53 + x * y * 11) % 3) + 1
    }

    private static func runTallGrassWind(on node: SKNode, x: Int, y: Int) {
        let seed = CGFloat((x * 17 + y * 31 + x * y * 7) % 100) / 100
        let swayA = CGFloat(0.014 + seed * 0.014)
        let swayB = CGFloat(-0.012 - seed * 0.012)
        let durationA = TimeInterval(0.72 + Double(seed) * 0.28)
        let durationB = TimeInterval(0.82 + Double(1 - seed) * 0.30)

        let leanA = SKAction.group([
            SKAction.rotate(toAngle: swayA, duration: durationA, shortestUnitArc: true),
            SKAction.scaleX(to: 0.992, y: 1.010, duration: durationA),
        ])
        let leanB = SKAction.group([
            SKAction.rotate(toAngle: swayB, duration: durationB, shortestUnitArc: true),
            SKAction.scaleX(to: 1.006, y: 0.996, duration: durationB),
        ])
        leanA.timingMode = .easeInEaseOut
        leanB.timingMode = .easeInEaseOut

        let sequence = SKAction.sequence([
            SKAction.wait(forDuration: TimeInterval(seed) * 0.75),
            SKAction.repeatForever(SKAction.sequence([leanA, leanB])),
        ])
        node.run(sequence, withKey: "grass-wind")
    }

    private static func applyGrassTint(to node: SKNode, variant: Int, cut: Bool) {
        guard let sprite = node as? SKSpriteNode else { return }
        sprite.color = cut ? cutGrassColor(for: variant) : tallGrassColor(for: variant)
        sprite.colorBlendFactor = cut ? 0.12 : 0.18
    }

    private static func tallGrassColor(for variant: Int) -> SKColor {
        switch variant {
        case 1: return SKColor(red: 0.14, green: 0.44, blue: 0.17, alpha: 1)
        case 2: return SKColor(red: 0.20, green: 0.55, blue: 0.20, alpha: 1)
        default: return SKColor(red: 0.18, green: 0.49, blue: 0.25, alpha: 1)
        }
    }

    private static func cutGrassColor(for variant: Int) -> SKColor {
        switch variant {
        case 1: return SKColor(red: 0.50, green: 0.72, blue: 0.26, alpha: 1)
        case 2: return SKColor(red: 0.59, green: 0.80, blue: 0.34, alpha: 1)
        default: return SKColor(red: 0.53, green: 0.76, blue: 0.30, alpha: 1)
        }
    }

    private static func firstAvailableTextureName(_ names: [String]) -> String {
        names.first(where: { textureIfAvailable($0) != nil }) ?? names.last ?? ""
    }

    private static let clippingTexture: SKTexture = {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 5, height: 5), format: format).image { context in
            UIColor(red: 0.30, green: 0.72, blue: 0.18, alpha: 1).setFill()
            context.cgContext.fill(CGRect(x: 1, y: 0, width: 3, height: 5))
            UIColor(red: 0.50, green: 0.92, blue: 0.28, alpha: 1).setFill()
            context.cgContext.fill(CGRect(x: 2, y: 0, width: 1, height: 4))
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .nearest
        return texture
    }()

    private static func textureIfAvailable(_ name: String) -> SKTexture? {
        // Bundle lookup is authoritative — SKTexture(imageNamed:) returns a
        // missing-resource placeholder if the image isn't found, but it has
        // non-zero size. Check Bundle.main for the actual file existence.
        if Bundle.main.url(forResource: name, withExtension: "png") != nil {
            return SKTexture(imageNamed: name)
        }
        // Check inside atlas folders too
        for atlas in ["mower", "cricket", "skunk", "stump", "tiles", "fx"] {
            if Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "\(atlas).atlas") != nil {
                return SKTexture(imageNamed: name)
            }
            if Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "Sprites/Goon/\(atlas).atlas") != nil {
                return SKTexture(imageNamed: name)
            }
            if Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "Resources/Sprites/Goon/\(atlas).atlas") != nil {
                return SKTexture(imageNamed: name)
            }
        }
        return nil
    }
}
