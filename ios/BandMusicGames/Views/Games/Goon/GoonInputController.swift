import SwiftUI

@MainActor
final class GoonInputController: ObservableObject {
    @Published var joystick: CGVector = .zero    // unit vector, magnitude 0–1
    @Published var digging: Bool = false
    @Published var canDig: Bool = false

    func reset() {
        joystick = .zero
        digging = false
    }
}
