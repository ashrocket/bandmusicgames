import SpriteKit

@MainActor
final class ForCuttingGrassRenderer {

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

    static func pushMowerNode(size: CGSize) -> SKNode {
        if let texture = textureIfAvailable("mower-body") {
            let node = SKSpriteNode(texture: texture, size: size)
            node.name = "push-mower"
            return node
        }

        let unit = min(size.width, size.height)
        let node = SKNode()
        node.name = "push-mower"

        // 1. Long Metal Handle
        let handlePath = CGMutablePath()
        handlePath.move(to: CGPoint(x: -unit * 0.15, y: 0))
        handlePath.addLine(to: CGPoint(x: -unit * 1.2, y: 0))
        let handle = SKShapeNode(path: handlePath)
        handle.strokeColor = SKColor(red: 0.6, green: 0.6, blue: 0.65, alpha: 1)
        handle.lineWidth = 3
        handle.zPosition = -1
        node.addChild(handle)
        
        // Wooden Grip
        let grip = SKShapeNode(rectOf: CGSize(width: 6, height: unit * 0.6), cornerRadius: 2)
        grip.fillColor = SKColor(red: 0.45, green: 0.3, blue: 0.2, alpha: 1)
        grip.strokeColor = .clear
        grip.position = CGPoint(x: -unit * 1.2, y: 0)
        node.addChild(grip)

        // 2. Main Cylinder Blades
        let cylinder = SKShapeNode(rectOf: CGSize(width: unit * 0.5, height: unit * 0.8), cornerRadius: 4)
        cylinder.fillColor = SKColor(red: 0.2, green: 0.2, blue: 0.25, alpha: 1)
        cylinder.strokeColor = SKColor(red: 0.4, green: 0.4, blue: 0.45, alpha: 1)
        cylinder.lineWidth = 1
        node.addChild(cylinder)
        
        // Blade Lines
        for i in -2...2 {
            let line = SKShapeNode(rectOf: CGSize(width: 2, height: unit * 0.8))
            line.fillColor = .white.withAlphaComponent(0.2)
            line.strokeColor = .clear
            line.position = CGPoint(x: CGFloat(i) * (unit * 0.1), y: 0)
            node.addChild(line)
        }

        // 3. Side Wheels
        let wheelY: CGFloat = unit * 0.45
        for side in [-1.0, 1.0] {
            let wheel = SKShapeNode(circleOfRadius: unit * 0.22)
            wheel.fillColor = SKColor(red: 0.1, green: 0.1, blue: 0.12, alpha: 1)
            wheel.strokeColor = SKColor(red: 0.5, green: 0.5, blue: 0.55, alpha: 1)
            wheel.lineWidth = 2
            wheel.position = CGPoint(x: 0, y: side * wheelY)
            node.addChild(wheel)
            
            let hub = SKShapeNode(circleOfRadius: 4)
            hub.fillColor = .gray
            hub.strokeColor = .clear
            hub.position = wheel.position
            node.addChild(hub)
        }

        return node
    }

    static func tileNode(for tile: ForCuttingGrassTile) -> SKNode {
        let size = CGSize(width: tileSize, height: tileSize)
        return tileNode(for: tile, size: size)
    }

    static func tileNode(for tile: ForCuttingGrassTile, size: CGSize) -> SKNode {
        switch tile {
        case .tall:    return sprite(named: "tile-tall-1",    size: size, fallbackColor: SKColor(red: 0.15, green: 0.38, blue: 0.12, alpha: 1))
        case .cut:     return sprite(named: "tile-cut-1",     size: size, fallbackColor: SKColor(red: 0.45, green: 0.65, blue: 0.25, alpha: 1))
        case .stump:   return sprite(named: "stump-full",     size: size, fallbackColor: SKColor(red: 0.45, green: 0.22, blue: 0.05, alpha: 1))
        case .house:   return houseTileNode(size: size)
        case .garden:  return flowerGardenTileNode(size: size)
        case .birdbath: return birdbathTileNode(size: size)
        }
    }

    private static func birdbathTileNode(size: CGSize) -> SKNode {
        let node = SKNode()
        let unit = min(size.width, size.height)
        
        // Base
        let base = SKShapeNode(rectOf: CGSize(width: 8, height: unit * 0.8))
        base.fillColor = SKColor(red: 0.6, green: 0.6, blue: 0.62, alpha: 1)
        base.strokeColor = .clear
        node.addChild(base)
        
        // Bowl
        let bowl = SKShapeNode(ellipseIn: CGRect(x: -unit * 0.4, y: unit * 0.2, width: unit * 0.8, height: unit * 0.4))
        bowl.fillColor = SKColor(red: 0.7, green: 0.7, blue: 0.72, alpha: 1)
        bowl.strokeColor = SKColor(red: 0.4, green: 0.4, blue: 0.42, alpha: 1)
        bowl.lineWidth = 1
        node.addChild(bowl)
        
        // Water
        let water = SKShapeNode(ellipseIn: CGRect(x: -unit * 0.3, y: unit * 0.25, width: unit * 0.6, height: unit * 0.25))
        water.fillColor = SKColor(red: 0.4, green: 0.7, blue: 0.9, alpha: 0.8)
        water.strokeColor = .clear
        node.addChild(water)
        
        return node
    }

    private static func houseTileNode(size: CGSize) -> SKNode {
        let node = SKNode()
        // Brick aesthetic
        let wall = SKShapeNode(rectOf: size)
        wall.fillColor = SKColor(red: 0.35, green: 0.22, blue: 0.18, alpha: 1)
        wall.strokeColor = SKColor(red: 0.25, green: 0.15, blue: 0.1, alpha: 1)
        wall.lineWidth = 1
        node.addChild(wall)
        
        // Mortar lines
        for i in 0...3 {
            let line = SKShapeNode(rectOf: CGSize(width: size.width, height: 1))
            line.fillColor = .white.withAlphaComponent(0.05)
            line.strokeColor = .clear
            line.position = CGPoint(x: 0, y: -size.height/2 + CGFloat(i) * (size.height/4))
            node.addChild(line)
        }

        return node
    }

    private static func flowerGardenTileNode(size: CGSize) -> SKNode {
        let node = SKNode()

        let foliage = SKShapeNode(rectOf: size)
        foliage.fillColor = SKColor(red: 0.08, green: 0.25, blue: 0.06, alpha: 1)
        foliage.strokeColor = .clear
        node.addChild(foliage)

        let flowerColors = [
            SKColor(red: 1.00, green: 0.42, blue: 0.71, alpha: 1), // Pink
            SKColor(red: 0.95, green: 0.82, blue: 0.15, alpha: 1), // Yellow
            SKColor(red: 0.82, green: 0.45, blue: 0.95, alpha: 1), // Purple
        ]
        
        for _ in 0...5 {
            let pos = CGPoint(x: CGFloat.random(in: -size.width/3...size.width/3),
                             y: CGFloat.random(in: -size.height/3...size.height/3))
            let bloom = SKShapeNode(circleOfRadius: 4)
            bloom.fillColor = flowerColors.randomElement()!
            bloom.strokeColor = .clear
            bloom.position = pos
            node.addChild(bloom)
        }

        return node
    }

    private static func textureIfAvailable(_ name: String) -> SKTexture? {
        // SpriteKit returns a "MissingResource" texture when the image isn't found,
        // but it has non-zero size. Use a Bundle lookup as authoritative.
        let texture = SKTexture(imageNamed: name)
        if texture.size() == .zero { return nil }

        if Bundle.main.url(forResource: name, withExtension: "png") != nil { return texture }

        // Check inside atlas folders too
        for atlas in ["mower", "cricket", "skunk", "stump", "tiles", "fx"] {
            if Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "\(atlas).atlas") != nil {
                return texture
            }
        }
        return nil
    }
}
