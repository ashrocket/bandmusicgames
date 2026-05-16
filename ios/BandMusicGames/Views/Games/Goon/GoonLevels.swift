import CoreGraphics

struct GoonLevelConfig {
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
}

enum GoonLevels {
    static let all: [GoonLevelConfig] = [
        GoonLevelConfig(
            n: 1, title: "LEVEL 1", sub: "THE HOUSE NEXT DOOR",
            desc: "Mow around the house and garden.",
            gasMax: 600, gasDrain: 0.10,
            cans: 0, stumps: 0, crickets: 0, skunks: 0, cricketMs: 0,
            win: 0.80
        ),
        GoonLevelConfig(
            n: 2, title: "LEVEL 2", sub: "RUNNING ON FUMES",
            desc: "Gas runs out — find the gas can!",
            gasMax: 200, gasDrain: 0.18,
            cans: 2, stumps: 0, crickets: 0, skunks: 0, cricketMs: 0,
            win: 0.80
        ),
        GoonLevelConfig(
            n: 3, title: "LEVEL 3", sub: "STUMP TROUBLE",
            desc: "Hold DIG near stumps to dig them up.",
            gasMax: 180, gasDrain: 0.20,
            cans: 2, stumps: 2, crickets: 0, skunks: 0, cricketMs: 0,
            win: 0.80
        ),
        GoonLevelConfig(
            n: 4, title: "LEVEL 4", sub: "CRICKET SEASON",
            desc: "Crickets hop around. Hit one = lose gas!  Watch the skunk!",
            gasMax: 160, gasDrain: 0.22,
            cans: 2, stumps: 2, crickets: 2, skunks: 1, cricketMs: 1200,
            win: 0.85
        ),
        GoonLevelConfig(
            n: 5, title: "LEVEL 5", sub: "THE FINAL YARD",
            desc: "Everything at once. Good luck.",
            gasMax: 140, gasDrain: 0.25,
            cans: 4, stumps: 3, crickets: 3, skunks: 2, cricketMs: 750,
            win: 0.90
        ),
    ]
}

enum GoonTile: UInt8 {
    case tall = 0      // mowable
    case cut = 1
    case stump = 2     // impassable until dug
    case house = 3     // impassable, not mowable
    case garden = 4    // passable, not mowable
}

struct GoonGrid {
    static let width = 25
    static let height = 15

    var cells: ContiguousArray<GoonTile>

    var cutPercentage: Double {
        var mowable = 0
        var cut = 0
        for cell in cells {
            switch cell {
            case .tall: mowable += 1
            case .cut: mowable += 1; cut += 1
            default: break
            }
        }
        return mowable == 0 ? 0 : Double(cut) / Double(mowable)
    }

    func at(_ x: Int, _ y: Int) -> GoonTile {
        guard x >= 0, x < Self.width, y >= 0, y < Self.height else { return .house }
        return cells[y * Self.width + x]
    }

    mutating func set(_ x: Int, _ y: Int, _ tile: GoonTile) {
        guard x >= 0, x < Self.width, y >= 0, y < Self.height else { return }
        cells[y * Self.width + x] = tile
    }

    mutating func cut(at x: Int, _ y: Int) {
        guard at(x, y) == .tall else { return }
        set(x, y, .cut)
    }

    static func make(for config: GoonLevelConfig) -> GoonGrid {
        var cells = ContiguousArray<GoonTile>(repeating: .tall, count: width * height)
        if config.n == 1 {
            // House footprint: 6×4 block at top-right corner (rows 1–4, cols 18–23)
            for y in 1...4 {
                for x in 18...23 {
                    cells[y * width + x] = .house
                }
            }
            // Garden bed: 2 rows of garden tiles below the house
            for y in 5...6 {
                for x in 18...23 {
                    cells[y * width + x] = .garden
                }
            }
        }
        return GoonGrid(cells: cells)
    }
}
