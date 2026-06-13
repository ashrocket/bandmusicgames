import CoreGraphics
import Foundation

struct ForCuttingGrassGasCan: Identifiable, Equatable {
    let id = UUID()
    var position: CGPoint
    var collected = false
}

struct ForCuttingGrassStump: Identifiable, Equatable {
    let id = UUID()
    var position: CGPoint
    var progress: CGFloat = 0   // 0..1
    var dug: Bool = false
}

struct ForCuttingGrassCricket: Identifiable, Equatable {
    let id = UUID()
    var position: CGPoint
    var velocity: CGVector
    var nextHopAt: TimeInterval
    var hitCooldownUntil: TimeInterval = 0
}

struct ForCuttingGrassSkunk: Identifiable, Equatable {
    let id = UUID()
    var position: CGPoint
    var velocity: CGVector
    var alarm: CGFloat   // 0..1
    var changeDirAt: TimeInterval
    var hitCooldownUntil: TimeInterval = 0
}

struct ForCuttingGrassLevelConfig {
    let n: Int
    let title: String
    let sub: String
    let desc: String
    let gasMax: CGFloat
    let gasDrain: CGFloat
    let cans: Int
    let stumps: Int
    let crickets: Int
    let skunks: Int
    let cricketMs: Int
    let win: CGFloat

    var usesGas: Bool { gasDrain > 0 }
}

enum ForCuttingGrassLevels {
    static let all: [ForCuttingGrassLevelConfig] = [
        ForCuttingGrassLevelConfig(
            n: 1, title: "LEVEL 1", sub: "THE HOUSE NEXT DOOR",
            desc: "Learn to steer around the house and flowers.",
            gasMax: 600, gasDrain: 0, cans: 0,
            stumps: 0, crickets: 0, skunks: 0, cricketMs: 0,
            win: 0.80
        ),
        ForCuttingGrassLevelConfig(
            n: 2, title: "LEVEL 2", sub: "LONG BACKYARD",
            desc: "Gas runs out. Find the gas cans.",
            gasMax: 200, gasDrain: 0.18, cans: 2,
            stumps: 0, crickets: 0, skunks: 0, cricketMs: 0,
            win: 0.80
        ),
        ForCuttingGrassLevelConfig(
            n: 3, title: "LEVEL 3", sub: "STUMP TROUBLE",
            desc: "Hold DIG near stumps to dig them up.",
            gasMax: 180, gasDrain: 0.20, cans: 2,
            stumps: 2, crickets: 0, skunks: 0, cricketMs: 0,
            win: 0.80
        ),
        ForCuttingGrassLevelConfig(
            n: 4, title: "LEVEL 4", sub: "CRICKET SEASON",
            desc: "Crickets hop around. Watch the skunk!",
            gasMax: 160, gasDrain: 0.22, cans: 2,
            stumps: 2, crickets: 2, skunks: 1, cricketMs: 1200,
            win: 0.85
        ),
        ForCuttingGrassLevelConfig(
            n: 5, title: "LEVEL 5", sub: "THE FINAL YARD",
            desc: "Everything at once. Good luck.",
            gasMax: 140, gasDrain: 0.25, cans: 4,
            stumps: 3, crickets: 3, skunks: 2, cricketMs: 750,
            win: 0.90
        ),
    ]
}

enum ForCuttingGrassTile: UInt8 {
    case tall = 0      // mowable
    case cut = 1
    case stump = 2     // impassable until dug
    case house = 3     // impassable, not mowable
    case garden = 4    // passable, not mowable
    case birdbath = 5  // impassable, not mowable
}

struct ForCuttingGrassGrid {
    static let width = 15
    static let height = 25

    var cells: ContiguousArray<ForCuttingGrassTile>

    var cutPercentage: Double {
        var mowable = 0
        var cutCount = 0
        for cell in cells {
            switch cell {
            case .tall: mowable += 1
            case .cut: mowable += 1; cutCount += 1
            default: break
            }
        }
        return mowable == 0 ? 0 : Double(cutCount) / Double(mowable)
    }

    func at(_ x: Int, _ y: Int) -> ForCuttingGrassTile {
        guard x >= 0, x < Self.width, y >= 0, y < Self.height else { return .house }
        return cells[y * Self.width + x]
    }

    mutating func set(_ x: Int, _ y: Int, _ tile: ForCuttingGrassTile) {
        guard x >= 0, x < Self.width, y >= 0, y < Self.height else { return }
        cells[y * Self.width + x] = tile
    }

    mutating func cut(at x: Int, _ y: Int) {
        guard at(x, y) == .tall else { return }
        set(x, y, .cut)
    }

    static func make(for config: ForCuttingGrassLevelConfig) -> ForCuttingGrassGrid {
        var cells = ContiguousArray<ForCuttingGrassTile>(repeating: .tall, count: width * height)
        if config.n == 1 {
            // High-Quality Garden Layout (Ref Image: ba.png)
            
            // 1. House at the top (2 tiles high)
            for y in 0...1 {
                for x in 0..<width {
                    cells[y * width + x] = .house
                }
            }
            
            // 2. Thick Flower beds on the sides (2 tiles wide)
            for y in 2..<height {
                // Left bed
                for x in 0...1 {
                    cells[y * width + x] = .garden
                }
                // Right bed
                for x in (width - 2)..<width {
                    cells[y * width + x] = .garden
                }
            }
            
            // 3. Flower bed at the bottom (2 tiles high)
            for y in (height - 3)..<(height - 1) {
                for x in 0..<width {
                    cells[y * width + x] = .garden
                }
            }
            
            // 4. Stone path at the very bottom (1 tile high)
            for x in 0..<width {
                cells[(height - 1) * width + x] = .garden // Paving
            }
            
            // 5. Birdbath obstacle (specifically on the left side of lawn)
            cells[14 * width + 2] = .birdbath
        }
        return ForCuttingGrassGrid(cells: cells)
    }
}
