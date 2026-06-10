import SwiftUI

enum ForCuttingGrassControlStyle: String, CaseIterable, Identifiable {
    case joystick
    case dpad
    case wheel
    case trackpad
    case lean

    var id: String { rawValue }

    var title: String {
        switch self {
        case .joystick: return "Stick"
        case .dpad: return "D-Pad"
        case .wheel: return "Wheel"
        case .trackpad: return "Drag"
        case .lean: return "Lean"
        }
    }

    var symbolName: String {
        switch self {
        case .joystick: return "circle.grid.cross"
        case .dpad: return "arrow.up.and.down.and.arrow.left.and.right"
        case .wheel: return "steeringwheel"
        case .trackpad: return "hand.draw"
        case .lean: return "arrow.left.and.right"
        }
    }

    var subtitle: String {
        switch self {
        case .joystick: return "Move freely in any direction"
        case .dpad: return "Snap to 8 directions"
        case .wheel: return "Steer, auto-drive forward"
        case .trackpad: return "Touch & pull the mower"
        case .lean: return "Tilt your device to steer"
        }
    }
}

@MainActor
final class ForCuttingGrassInputController: ObservableObject {
    @Published var joystick: CGVector = .zero    // direction vector
    @Published var throttle: CGFloat = 0         // speed scalar, 0...1
    @Published var digging: Bool = false
    @Published var canDig: Bool = false
    @Published var controlStyle: ForCuttingGrassControlStyle {
        didSet {
            UserDefaults.standard.set(controlStyle.rawValue, forKey: Self.savedControlStyleKey)
            joystick = .zero
            throttle = 0
            digging = false
        }
    }

    private static let savedControlStyleKey = "for_cutting_grass_control_style"

    init() {
        let saved = UserDefaults.standard.string(forKey: Self.savedControlStyleKey)
        controlStyle = saved.flatMap(ForCuttingGrassControlStyle.init(rawValue:)) ?? .joystick
    }

    func reset() {
        joystick = .zero
        throttle = 0
        digging = false
    }
}
