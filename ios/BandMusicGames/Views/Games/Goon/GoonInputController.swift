import SwiftUI

@MainActor
final class GoonInputController: ObservableObject {
    @Published var joystick: CGVector = .zero    // LEFT stick: left-wheel control
    @Published var joystick2: CGVector = .zero   // RIGHT stick: right-wheel control
    @Published var digging: Bool = false
    @Published var canDig: Bool = false

    func reset() {
        joystick = .zero
        joystick2 = .zero
        digging = false
    }
}
