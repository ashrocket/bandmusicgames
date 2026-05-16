import SpriteKit

@MainActor
enum GoonRenderer {

    static let tileSize: CGFloat = 32

    /// Look up a sprite by name; if no texture atlas is present yet,
    /// return a colored shape-node fallback so day-1 build is playable.
    static func sprite(named name: String, size: CGSize, fallbackColor: SKColor) -> SKNode {
        if let texture = textureIfAvailable(name) {
            let node = SKSpriteNode(texture: texture, size: size)
            node.name = name
            return node
        }
        let shape = SKShapeNode(rectOf: size, cornerRadius: 2)
        shape.fillColor = fallbackColor
        shape.strokeColor = .clear
        shape.name = name
        return shape
    }

    static func tileNode(for tile: GoonTile) -> SKNode {
        let size = CGSize(width: tileSize, height: tileSize)
        switch tile {
        case .tall:    return sprite(named: "tile-tall-1",    size: size, fallbackColor: SKColor(red: 0.18, green: 0.48, blue: 0.18, alpha: 1))
        case .cut:     return sprite(named: "tile-cut-1",     size: size, fallbackColor: SKColor(red: 0.55, green: 0.77, blue: 0.29, alpha: 1))
        case .stump:   return sprite(named: "stump-full",     size: size, fallbackColor: SKColor(red: 0.55, green: 0.27, blue: 0.07, alpha: 1))
        case .house:   return sprite(named: "tile-house-wall", size: size, fallbackColor: SKColor(red: 0.4,  green: 0.3,  blue: 0.2,  alpha: 1))
        case .garden:  return sprite(named: "tile-garden-1",   size: size, fallbackColor: SKColor(red: 0.6,  green: 0.4,  blue: 0.7,  alpha: 1))
        }
    }

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
        }
        return nil
    }
}
