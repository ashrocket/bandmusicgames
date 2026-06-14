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
    let timeLimit: TimeInterval
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
            lore: "Her distinctive **W** shape is one of the easiest patterns to find in the northern sky. Visible all year round from most of the Northern Hemisphere, best seen in autumn.",
            timeLimit: 60
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
            lore: "Deneb, its brightest star, marks the swan's tail and is one of the three stars in the Summer Triangle. It is often depicted flying south along the Milky Way.",
            timeLimit: 60
        ),
        FrancisLevelConfig(
            n: 3,
            constellationName: "Orion",
            subtitle: "the Hunter",
            description: "One of the most famous constellations in the sky, dominated by the three-star belt. In Greek mythology, Orion was a giant huntsman placed in the stars by Zeus after his death.",
            stars: [
                FrancisStarConfig(nx: 0.26, ny: 0.22, name: "α · Betelgeuse · \"the armpit\""),
                FrancisStarConfig(nx: 0.74, ny: 0.20, name: "γ · Bellatrix · \"the female warrior\""),
                FrancisStarConfig(nx: 0.36, ny: 0.48, name: "ζ · Alnitak · \"the belt\""),
                FrancisStarConfig(nx: 0.50, ny: 0.52, name: "ε · Alnilam · \"the belt\""),
                FrancisStarConfig(nx: 0.64, ny: 0.48, name: "δ · Mintaka · \"the belt\""),
                FrancisStarConfig(nx: 0.26, ny: 0.78, name: "κ · Saiph · \"the sword\""),
                FrancisStarConfig(nx: 0.74, ny: 0.75, name: "β · Rigel · \"the left foot\"")
            ],
            edges: [(0, 2), (1, 4), (2, 3), (3, 4), (2, 5), (4, 6)],
            lore: "Rigel and Betelgeuse are contrasting giants — Rigel burns blue-white while Betelgeuse glows red. Betelgeuse is a red supergiant expected to explode as a supernova within 100,000 years.",
            timeLimit: 90
        ),
        FrancisLevelConfig(
            n: 4,
            constellationName: "Leo",
            subtitle: "the Lion",
            description: "One of the twelve constellations of the zodiac. The Sickle asterism forms the lion's mane and head, while Denebola marks the tail. The Sun passes through Leo in late summer.",
            stars: [
                FrancisStarConfig(nx: 0.40, ny: 0.75, name: "α · Regulus · \"the little king\""),
                FrancisStarConfig(nx: 0.30, ny: 0.58, name: "η · Eta Leonis · unnamed"),
                FrancisStarConfig(nx: 0.24, ny: 0.42, name: "γ · Algieba · \"the mane\""),
                FrancisStarConfig(nx: 0.26, ny: 0.26, name: "ζ · Adhafera · unnamed"),
                FrancisStarConfig(nx: 0.40, ny: 0.18, name: "μ · Rasalas · \"the northern star of Leo\""),
                FrancisStarConfig(nx: 0.65, ny: 0.55, name: "θ · Chertan · \"the ribs\""),
                FrancisStarConfig(nx: 0.82, ny: 0.48, name: "β · Denebola · \"the lion's tail\"")
            ],
            edges: [(0, 1), (1, 2), (2, 3), (3, 4), (0, 5), (5, 6)],
            lore: "Regulus, the brightest star in Leo, sits almost exactly on the ecliptic — the Sun's annual path across the sky. It spins so fast that it bulges noticeably at its equator.",
            timeLimit: 90
        ),
        FrancisLevelConfig(
            n: 5,
            constellationName: "Scorpius",
            subtitle: "the Scorpion",
            description: "A zodiac constellation with a distinctive curved tail that really does look like a scorpion. In mythology, it is the creature sent by the goddess Artemis to slay Orion — which is why they never appear in the sky together.",
            stars: [
                FrancisStarConfig(nx: 0.24, ny: 0.20, name: "σ · Alniyat · \"the arteries\""),
                FrancisStarConfig(nx: 0.38, ny: 0.26, name: "α · Antares · \"rival of Mars\""),
                FrancisStarConfig(nx: 0.52, ny: 0.30, name: "τ · Tau Scorpii · unnamed"),
                FrancisStarConfig(nx: 0.66, ny: 0.38, name: "ε · Larawag · \"the heart\""),
                FrancisStarConfig(nx: 0.74, ny: 0.52, name: "μ · Shaula · \"the sting\""),
                FrancisStarConfig(nx: 0.68, ny: 0.68, name: "λ · Lesath · \"the tail tip\""),
                FrancisStarConfig(nx: 0.54, ny: 0.78, name: "υ · Upsilon Scorpii · unnamed")
            ],
            edges: [(0, 1), (1, 2), (2, 3), (3, 4), (4, 5), (5, 6)],
            lore: "Antares, a red supergiant at the scorpion's heart, is so large that if placed at the center of our solar system, it would engulf Mercury, Venus, Earth, and Mars.",
            timeLimit: 120
        )
    ]
}
