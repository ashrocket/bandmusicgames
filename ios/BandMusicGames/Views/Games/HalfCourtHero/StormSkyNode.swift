import SpriteKit

/// Pure mapping from the SHOOT charge value to a storm visual stage.
/// Window semantics must match HalfCourtHeroScene.shotError(): green and
/// perfect bounds are inclusive; past greenHigh the window is gone.
enum StormStage: Equatable {
    case clear
    case building(progress: CGFloat)   // 0...1 — how close the window is
    case green(perfect: Bool)
    case parted

    static func stage(charge: CGFloat?,
                      greenLow: CGFloat, greenHigh: CGFloat,
                      perfectLow: CGFloat, perfectHigh: CGFloat) -> StormStage {
        guard let c = charge else { return .clear }
        if c > greenHigh { return .parted }
        if c >= greenLow { return .green(perfect: c >= perfectLow && c <= perfectHigh) }
        return .building(progress: max(0, min(1, c / greenLow)))
    }

    /// Stage identity ignoring associated values — for one-shot transitions.
    var kind: Int {
        switch self {
        case .clear: return 0
        case .building: return 1
        case .green: return 2
        case .parted: return 3
        }
    }
}
