import SwiftUI

@MainActor
final class FrattypipelineInputController: ObservableObject {
    @Published var joystick: CGVector = .zero
    @Published var barking: Bool = false

    func triggerBark() {
        barking = true
    }

    func consumeBark() -> Bool {
        guard barking else { return false }
        barking = false
        return true
    }

    func reset() {
        joystick = .zero
        barking = false
    }
}
