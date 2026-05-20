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

        let handlePath = CGMutablePath()
        handlePath.move(to: CGPoint(x: -unit * 0.28, y: unit * 0.18))
        handlePath.addLine(to: CGPoint(x: -unit * 0.82, y: unit * 0.54))
        handlePath.addLine(to: CGPoint(x: -unit * 1.03, y: unit * 0.54))
        handlePath.move(to: CGPoint(x: -unit * 0.28, y: -unit * 0.18))
        handlePath.addLine(to: CGPoint(x: -unit * 0.82, y: -unit * 0.54))
        handlePath.addLine(to: CGPoint(x: -unit * 1.03, y: -unit * 0.54))
        let handle = SKShapeNode(path: handlePath)
        handle.strokeColor = SKColor(red: 0.72, green: 0.80, blue: 0.70, alpha: 1)
        handle.lineWidth = max(2, unit * 0.07)
        handle.lineCap = .round
        handle.lineJoin = .round
        handle.zPosition = -1
        node.addChild(handle)

        let deckSize = CGSize(width: unit * 0.98, height: unit * 0.60)
        let deck = SKShapeNode(rectOf: deckSize, cornerRadius: unit * 0.12)
        deck.fillColor = SKColor(red: 0.93, green: 0.72, blue: 0.18, alpha: 1)
        deck.strokeColor = SKColor(red: 0.34, green: 0.22, blue: 0.04, alpha: 1)
        deck.lineWidth = max(1, unit * 0.04)
        deck.position = CGPoint(x: unit * 0.06, y: 0)
        node.addChild(deck)

        let cowling = SKShapeNode(rectOf: CGSize(width: unit * 0.44, height: unit * 0.34), cornerRadius: unit * 0.08)
        cowling.fillColor = SKColor(red: 0.98, green: 0.86, blue: 0.30, alpha: 1)
        cowling.strokeColor = SKColor(red: 0.42, green: 0.27, blue: 0.05, alpha: 1)
        cowling.lineWidth = max(1, unit * 0.025)
        cowling.position = CGPoint(x: unit * 0.16, y: 0)
        node.addChild(cowling)

        let vent = SKShapeNode(rectOf: CGSize(width: unit * 0.22, height: unit * 0.06), cornerRadius: unit * 0.02)
        vent.fillColor = SKColor(red: 0.27, green: 0.22, blue: 0.10, alpha: 1)
        vent.strokeColor = .clear
        vent.position = CGPoint(x: unit * 0.17, y: 0)
        node.addChild(vent)

        let nose = SKShapeNode(rectOf: CGSize(width: unit * 0.22, height: unit * 0.42), cornerRadius: unit * 0.06)
        nose.fillColor = SKColor(red: 0.28, green: 0.61, blue: 0.18, alpha: 1)
        nose.strokeColor = SKColor(red: 0.08, green: 0.22, blue: 0.06, alpha: 1)
        nose.lineWidth = max(1, unit * 0.025)
        nose.position = CGPoint(x: unit * 0.47, y: 0)
        node.addChild(nose)

        let wheelPositions = [
            CGPoint(x: -unit * 0.27, y: -unit * 0.36),
            CGPoint(x: unit * 0.34, y: -unit * 0.36),
            CGPoint(x: -unit * 0.27, y: unit * 0.36),
            CGPoint(x: unit * 0.34, y: unit * 0.36),
        ]
        for position in wheelPositions {
            let wheel = SKShapeNode(circleOfRadius: unit * 0.12)
            wheel.fillColor = SKColor(red: 0.07, green: 0.08, blue: 0.06, alpha: 1)
            wheel.strokeColor = SKColor(red: 0.65, green: 0.70, blue: 0.58, alpha: 1)
            wheel.lineWidth = max(1, unit * 0.025)
            wheel.position = position
            node.addChild(wheel)

            let hub = SKShapeNode(circleOfRadius: unit * 0.045)
            hub.fillColor = SKColor(red: 0.80, green: 0.78, blue: 0.58, alpha: 1)
            hub.strokeColor = .clear
            hub.position = position
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
        case .tall:    return sprite(named: "tile-tall-1",    size: size, fallbackColor: SKColor(red: 0.18, green: 0.48, blue: 0.18, alpha: 1))
        case .cut:     return sprite(named: "tile-cut-1",     size: size, fallbackColor: SKColor(red: 0.55, green: 0.77, blue: 0.29, alpha: 1))
        case .stump:   return sprite(named: "stump-full",     size: size, fallbackColor: SKColor(red: 0.55, green: 0.27, blue: 0.07, alpha: 1))
        case .house:   return houseTileNode(size: size)
        case .garden:  return flowerGardenTileNode(size: size)
        }
    }

    private static func houseTileNode(size: CGSize) -> SKNode {
        let node = SKNode()

        let roof = SKShapeNode(rectOf: size)
        roof.fillColor = SKColor(red: 0.40, green: 0.09, blue: 0.08, alpha: 1)
        roof.strokeColor = SKColor(red: 0.20, green: 0.04, blue: 0.03, alpha: 1)
        roof.lineWidth = 1
        node.addChild(roof)

        let highlight = SKShapeNode(rectOf: CGSize(width: max(2, size.width - 6), height: max(2, size.height * 0.12)))
        highlight.fillColor = SKColor(red: 0.64, green: 0.20, blue: 0.16, alpha: 0.75)
        highlight.strokeColor = .clear
        highlight.position = CGPoint(x: 0, y: size.height * 0.18)
        node.addChild(highlight)

        return node
    }

    private static func flowerGardenTileNode(size: CGSize) -> SKNode {
        let node = SKNode()

        let soil = SKShapeNode(rectOf: size)
        soil.fillColor = SKColor(red: 0.24, green: 0.12, blue: 0.04, alpha: 1)
        soil.strokeColor = SKColor(red: 0.50, green: 0.32, blue: 0.10, alpha: 0.7)
        soil.lineWidth = 1
        node.addChild(soil)

        let flowerColors = [
            SKColor(red: 1.00, green: 0.40, blue: 0.55, alpha: 1),
            SKColor(red: 1.00, green: 0.88, blue: 0.20, alpha: 1),
            SKColor(red: 0.42, green: 0.85, blue: 1.00, alpha: 1),
            SKColor(red: 0.94, green: 0.48, blue: 1.00, alpha: 1),
        ]
        let centers = [
            CGPoint(x: -size.width * 0.24, y: -size.height * 0.22),
            CGPoint(x: size.width * 0.22, y: -size.height * 0.12),
            CGPoint(x: -size.width * 0.10, y: size.height * 0.22),
        ]

        for (index, center) in centers.enumerated() {
            let stem = SKShapeNode(rectOf: CGSize(width: max(1, size.width * 0.07), height: max(4, size.height * 0.32)))
            stem.fillColor = SKColor(red: 0.13, green: 0.52, blue: 0.13, alpha: 1)
            stem.strokeColor = .clear
            stem.position = CGPoint(x: center.x, y: center.y - size.height * 0.10)
            node.addChild(stem)

            let bloom = SKShapeNode(circleOfRadius: max(2, min(size.width, size.height) * 0.14))
            bloom.fillColor = flowerColors[index % flowerColors.count]
            bloom.strokeColor = .clear
            bloom.position = center
            node.addChild(bloom)

            let middle = SKShapeNode(circleOfRadius: max(0.8, min(size.width, size.height) * 0.05))
            middle.fillColor = SKColor(red: 1.0, green: 0.92, blue: 0.15, alpha: 1)
            middle.strokeColor = .clear
            middle.position = center
            node.addChild(middle)
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
