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
