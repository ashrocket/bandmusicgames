import SwiftUI
import CoreGraphics

enum HalfCourtPhase {
    case title
    case characterSelect
    case playing
    case ended
}

enum HalfCourtTeam {
    case home
    case away
}

enum HalfCourtAnimation: String, CaseIterable {
    case idle
    case run
    case dribble
    case jump
    case land
    case shoot
    case celebrate
    case sad
}

struct HalfCourtStats {
    var shots = 0
    var made = 0
    var steals = 0
    var blocks = 0
    var threes = 0
    var homeSeriesWins = 0
    var awaySeriesWins = 0
}

struct HalfCourtCallout: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let color: Color

    static func == (lhs: HalfCourtCallout, rhs: HalfCourtCallout) -> Bool {
        lhs.id == rhs.id
    }
}

enum HalfCourtDifficulty: String, CaseIterable, Identifiable {
    case easy
    case normal
    case hard

    var id: String { rawValue }
    var label: String { rawValue.uppercased() }

    var greenWindow: (low: CGFloat, high: CGFloat) {
        switch self {
        case .easy: return (52 - 14, 76 + 14)
        case .normal: return (52, 76)
        case .hard: return (52 + 5, 76 - 5)
        }
    }

    var perfectAccuracy: CGFloat {
        switch self {
        case .easy: return 1
        case .normal: return 0.95
        case .hard: return 0.92
        }
    }

    var greenAccuracy: CGFloat {
        switch self {
        case .easy: return 0.96
        case .normal: return 0.88
        case .hard: return 0.78
        }
    }

    var lateAccuracy: CGFloat {
        switch self {
        case .easy: return 0.5
        case .normal: return 0.32
        case .hard: return 0.18
        }
    }

    var cpuDriveSpeed: CGFloat {
        switch self {
        case .easy: return 1.65
        case .normal: return 2.2
        case .hard: return 2.8
        }
    }

    var cpuShotMultiplier: CGFloat {
        switch self {
        case .easy: return 1.35   // larger error range → CPU misses more
        case .normal: return 1.0
        case .hard: return 0.58   // smaller error range → CPU is accurate
        }
    }

    var cpuStealRate: CGFloat {
        switch self {
        case .easy: return 0.10
        case .normal: return 0.20
        case .hard: return 0.32
        }
    }

    var shotClockSeconds: TimeInterval {
        switch self {
        case .easy: return 13
        case .normal: return 10
        case .hard: return 7
        }
    }

    /// Rate at which holding the action zone fills the shot meter (0–1 scale per second).
    /// Faster = narrower reaction window inside the green zone.
    var chargeRate: CGFloat {
        switch self {
        case .easy: return 0.75   // ~320ms window inside green
        case .normal: return 0.95 // ~250ms window inside green
        case .hard: return 1.10   // ~220ms window inside green
        }
    }
}

/// On-screen control scheme for HalfCourtHero (Nara's Room). Selected on the
/// pre-game title screen and persisted in `UserDefaults`. The legacy gesture
/// scheme (drag-to-move + flick-to-shoot) has been retired in favour of
/// on-screen buttons; movement stays on the left-thumb joystick in both modes.
enum HalfCourtControlStyle: String, CaseIterable, Identifiable {
    /// Hoop Land style: PASS + hold-to-charge SHOOT on offense; the same two
    /// buttons relabel to STEAL + BLOCK on defense.
    case hoopLand
    /// Basketball Battle style: PASS + a single JUMP button. On offense a tap
    /// jumps and auto-releases the shot at the apex (no meter); on defense the
    /// JUMP button blocks/contests. PASS relabels to STEAL on defense.
    case jumpBall

    var id: String { rawValue }

    /// UserDefaults key shared by the scene (read) and the title-screen selector (write).
    static let storageKey = "half_court_control_style"

    var title: String {
        switch self {
        case .hoopLand: return "HoopLand"
        case .jumpBall: return "JumpBall"
        }
    }

    var subtitle: String {
        switch self {
        case .hoopLand: return "Hold to charge your shot"
        case .jumpBall: return "Tap to jump & auto-shoot"
        }
    }

    /// HoopLand shows the hold-to-charge power meter; JumpBall never does.
    var usesChargeMeter: Bool { self == .hoopLand }

    /// Current persisted style, defaulting to `.hoopLand`.
    static func loadPersisted() -> HalfCourtControlStyle {
        let saved = UserDefaults.standard.string(forKey: storageKey)
        return saved.flatMap(HalfCourtControlStyle.init(rawValue:)) ?? .hoopLand
    }
}

enum HalfCourtHeroID: String, CaseIterable, Identifiable {
    case nara
    case ethan
    case brendan
    case will

    var id: String { rawValue }

    var character: HalfCourtHero {
        switch self {
        case .nara:
            return HalfCourtHero(
                name: "NARA",
                fullName: "NARA AVAKIAN",
                role: "VOCALS / GUITAR",
                ability: "3PT SHOOTER",
                abilityBlurb: "Deadeye from beyond the arc. Leave her open out there and it's MONEY.",
                hue: Color(hex: "#FF1493"),
                skin: Color(hex: "#FDBCB4"),
                hair: Color(hex: "#1C0A00"),
                shirt: Color(hex: "#222222"),
                pants: Color(hex: "#3366DD"),
                shoes: Color(hex: "#2A2A2A"),
                hairStyle: .bob,
                threeBonus: 0.10,
                closeBonus: 0,
                stealBonus: 0,
                speed: 1.0,
                height: 175,
                quip: "MONEY"
            )
        case .ethan:
            return HalfCourtHero(
                name: "ETHAN",
                fullName: "ETHAN NASH",
                role: "BASS",
                ability: "LOCKDOWN",
                abilityBlurb: "A glove on defense — quick feet and a hand in every passing lane. Straight FIRE.",
                hue: Color(hex: "#32CD32"),
                skin: Color(hex: "#C68642"),
                hair: Color(hex: "#3D2B1F"),
                shirt: Color(hex: "#32CD32"),
                pants: Color(hex: "#1C1C2E"),
                shoes: .white,
                hairStyle: .long,
                threeBonus: 0,
                closeBonus: 0,
                stealBonus: 0.20,
                speed: 1.05,
                height: 180,
                quip: "FIRE"
            )
        case .brendan:
            return HalfCourtHero(
                name: "BRENDAN",
                fullName: "BRENDAN JONES",
                role: "DRUMS",
                ability: "PAINT BEAST",
                abilityBlurb: "Owns the paint. Strong drives, stronger finishes. BOOM.",
                hue: Color(hex: "#FF6B35"),
                skin: Color(hex: "#FDBCB4"),
                hair: Color(hex: "#CC2200"),
                shirt: Color(hex: "#FF6B35"),
                pants: Color(hex: "#2D5A27"),
                shoes: Color(hex: "#222222"),
                hairStyle: .beanie,
                threeBonus: 0,
                closeBonus: 0.18,
                stealBonus: 0,
                speed: 1.0,
                height: 185,
                quip: "BOOM"
            )
        case .will:
            return HalfCourtHero(
                name: "WILL",
                fullName: "WILL FISHER",
                role: "KEYS",
                ability: "DEEP RANGE",
                abilityBlurb: "Limitless range off the keys — pulls from the logo like it's a layup. PERFECT.",
                hue: Color(hex: "#9B59B6"),
                skin: Color(hex: "#8D5524"),
                hair: Color(hex: "#111111"),
                shirt: Color(hex: "#9B59B6"),
                pants: Color(hex: "#2C2C2C"),
                shoes: Color(hex: "#9B59B6"),
                hairStyle: .glasses,
                threeBonus: 0.08,
                closeBonus: 0,
                stealBonus: 0,
                speed: 0.95,
                height: 174,
                quip: "PERFECT"
            )
        }
    }
}

struct HalfCourtHero {
    let name: String
    let fullName: String
    let role: String
    let ability: String
    let abilityBlurb: String
    let hue: Color
    let skin: Color
    let hair: Color
    let shirt: Color
    let pants: Color
    let shoes: Color
    let hairStyle: HairStyle
    let threeBonus: CGFloat
    let closeBonus: CGFloat  // error reduction on non-arc shots
    let stealBonus: CGFloat  // extra contest pressure on CPU shots
    let speed: CGFloat
    let height: CGFloat
    let quip: String

    enum HairStyle {
        case bob
        case long
        case beanie
        case glasses
    }
}
