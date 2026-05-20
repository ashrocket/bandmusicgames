import CoreGraphics
import Foundation

struct FrancisStarConfig {
    let nx: Double
    let ny: Double
    let name: String
}

struct FrancisLevelConfig {
    let n: Int
    let constellationName: String
    let subtitle: String
    let description: String
    let stars: [FrancisStarConfig]
    let edges: [(Int, Int)]
    let lore: String
}

enum FrancisLevels {
    static let all: [FrancisLevelConfig] = [
        FrancisLevelConfig(
            n: 1,
            constellationName: "Cassiopeia",
            subtitle: "the Seated Queen",
            description: "Named for the vain queen of Greek myth, punished by the sea god Poseidon to circle the north celestial pole for eternity, seated on her throne.",
            stars: [
                FrancisStarConfig(nx: 0.18, ny: 0.35, name: "α · Schedar · \"the breast\""),
                FrancisStarConfig(nx: 0.35, ny: 0.52, name: "β · Caph · \"the palm\""),
                FrancisStarConfig(nx: 0.52, ny: 0.28, name: "γ · Gamma Cassiopeiae · unnamed"),
                FrancisStarConfig(nx: 0.72, ny: 0.62, name: "δ · Ruchbah · \"the knee\""),
                FrancisStarConfig(nx: 0.88, ny: 0.38, name: "ε · Segin · unnamed")
            ],
            edges: [(0, 1), (1, 2), (2, 3), (3, 4)],
            lore: "Her distinctive **W** shape is one of the easiest patterns to find in the northern sky. Visible all year round from most of the Northern Hemisphere, best seen in autumn."
        ),
        FrancisLevelConfig(
            n: 2,
            constellationName: "Cygnus",
            subtitle: "the Swan",
            description: "One of the most recognizable constellations of the northern summer and autumn sky, featuring a prominent asterism known as the Northern Cross.",
            stars: [
                FrancisStarConfig(nx: 0.5, ny: 0.15, name: "α · Deneb · \"the tail\""),
                FrancisStarConfig(nx: 0.5, ny: 0.4, name: "γ · Sadr · \"the chest\""),
                FrancisStarConfig(nx: 0.2, ny: 0.35, name: "δ · Delta Cygni · unnamed"),
                FrancisStarConfig(nx: 0.8, ny: 0.45, name: "ε · Aljanah · \"the wing\""),
                FrancisStarConfig(nx: 0.5, ny: 0.8, name: "β · Albireo · \"the beak\"")
            ],
            edges: [(0, 1), (1, 2), (1, 3), (1, 4)],
            lore: "Deneb, its brightest star, marks the swan's tail and is one of the three stars in the Summer Triangle. It is often depicted flying south along the Milky Way."
        )
    ]
}
